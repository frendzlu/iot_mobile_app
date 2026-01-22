#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_netif.h"
#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_gap_ble_api.h"
#include "esp_gatts_api.h"
#include "esp_gatt_common_api.h"
#include "lwip/err.h"
#include "lwip/sys.h"
#include "mqtt_client.h"
#include "cJSON.h"

#define GATTS_TAG "BLE_WIFI_CONFIG"
#define WIFI_TAG "WIFI_CONFIG"
#define MQTT_TAG "MQTT_CLIENT"
#define PROFILE_APP_ID 0
#define WIFI_NUM_HANDLE 4
#define MAX_PROVISION_DATA 512  // Increased for JSON data

// WiFi event bits
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

// Custom 128-bit UUIDs (from your friend's code)
#define WIFI_SVC_UUID_128   {0x23,0x01,0x12,0x34,0x56,0x78,0x90,0xAB,0xCD,0xEF,0x01,0x23,0x45,0x67,0x89,0xAB}
#define WIFI_CHAR_UUID_128  {0x23,0x02,0x12,0x34,0x56,0x78,0x90,0xAB,0xCD,0xEF,0x01,0x23,0x45,0x67,0x89,0xAB}

// --- Global Variables ---
static uint8_t provisioning_data[MAX_PROVISION_DATA] = {0};
static size_t provisioning_data_len = 0;
static bool is_prepared_write = false;
static uint16_t prepare_write_handle = 0;

// Device configuration
static char device_name[64] = {0};
static char wifi_ssid[64] = {0};
static char wifi_password[64] = {0};
static char user_uuid[64] = {0};
static char user_password[64] = {0};
static char backend_url[128] = {0};
static char broker_url[128] = {0};
static char device_mac[18] = {0};

// Status tracking
static bool wifi_connected = false;
static bool mqtt_connected = false;
static bool device_registered = false;
static char last_error[256] = {0};

// Event group for WiFi events
static EventGroupHandle_t s_wifi_event_group;
static int s_retry_num = 0;
static const int MAX_RETRY = 5;

// MQTT client
static esp_mqtt_client_handle_t mqtt_client = NULL;

// BLE handles
static esp_gatt_char_prop_t wifi_property = ESP_GATT_CHAR_PROP_BIT_WRITE | ESP_GATT_CHAR_PROP_BIT_WRITE_NR | ESP_GATT_CHAR_PROP_BIT_NOTIFY;
static uint16_t notify_conn_id = 0;
static uint16_t notify_handle = 0;
static bool notify_enabled = false;

static esp_attr_value_t wifi_attr = {
    .attr_max_len = MAX_PROVISION_DATA,
    .attr_len = 1,
    .attr_value = provisioning_data,
};

static esp_ble_adv_data_t adv_data = {
    .set_scan_rsp = false,
    .include_name = true,
    .include_txpower = false,
    .appearance = 0x00,
    .flag = (ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT),
};

static esp_ble_adv_params_t adv_params = {
    .adv_int_min        = 0x20,
    .adv_int_max        = 0x40,
    .adv_type           = ADV_TYPE_IND,
    .own_addr_type      = BLE_ADDR_TYPE_PUBLIC,
    .channel_map        = ADV_CHNL_ALL,
    .adv_filter_policy  = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY,
};

struct gatts_profile_inst {
    esp_gatts_cb_t gatts_cb;
    uint16_t gatts_if;
    uint16_t app_id;
    uint16_t conn_id;
    uint16_t service_handle;
    esp_gatt_srvc_id_t service_id;
    uint16_t char_handle;
    esp_bt_uuid_t char_uuid;
    uint16_t descr_handle;
};

static struct gatts_profile_inst profile_tab[1];

// Function prototypes
static void send_device_status(void);
static void send_error_status(const char* error_msg);
static void parse_provisioning_data(const char* json_data);
static void connect_to_wifi(void);
static void connect_to_mqtt(void);
static void register_device(void);
static void get_device_mac_address(void);

// --- Send device status via BLE ---
static void send_device_status(void) {
    if (!notify_enabled || notify_conn_id == 0) return;

    cJSON *status = cJSON_CreateObject();
    cJSON_AddStringToObject(status, "deviceName", device_name);
    if (strlen(device_mac) > 0) {
        cJSON_AddStringToObject(status, "macAddress", device_mac);
    }
    cJSON_AddBoolToObject(status, "wifiConnected", wifi_connected);
    cJSON_AddBoolToObject(status, "mqttConnected", mqtt_connected);
    cJSON_AddBoolToObject(status, "registered", device_registered);
    
    if (wifi_connected && strlen(wifi_ssid) > 0) {
        cJSON_AddStringToObject(status, "wifiSsid", wifi_ssid);
    }
    if (mqtt_connected && strlen(broker_url) > 0) {
        cJSON_AddStringToObject(status, "mqttBrokerUrl", broker_url);
    }
    if (strlen(last_error) > 0) {
        cJSON_AddStringToObject(status, "error", last_error);
        memset(last_error, 0, sizeof(last_error)); // Clear after sending
    }
    
    // Add timestamp
    char timestamp[32];
    time_t now = time(NULL);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
    cJSON_AddStringToObject(status, "timestamp", timestamp);

    char *status_string = cJSON_Print(status);
    if (status_string) {
        esp_ble_gatts_send_indicate(profile_tab[0].gatts_if, notify_conn_id, notify_handle,
                                   strlen(status_string), (uint8_t*)status_string, false);
        ESP_LOGI(GATTS_TAG, "Sent status: %s", status_string);
        free(status_string);
    }
    cJSON_Delete(status);
}

// --- Send error status ---
static void send_error_status(const char* error_msg) {
    strncpy(last_error, error_msg, sizeof(last_error) - 1);
    last_error[sizeof(last_error) - 1] = '\0';
    send_device_status();
}

// --- Get device MAC address ---
static void get_device_mac_address(void) {
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(device_mac, sizeof(device_mac), "%02X:%02X:%02X:%02X:%02X:%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    ESP_LOGI(WIFI_TAG, "Device MAC: %s", device_mac);
}

// --- Parse JSON provisioning data ---
static void parse_provisioning_data(const char* json_data) {
    ESP_LOGI(GATTS_TAG, "Parsing JSON: %s", json_data);
    
    cJSON *json = cJSON_Parse(json_data);
    if (json == NULL) {
        const char *error_ptr = cJSON_GetErrorPtr();
        ESP_LOGE(GATTS_TAG, "JSON parsing error: %s", error_ptr ? error_ptr : "unknown error");
        send_error_status("Invalid JSON format");
        return;
    }

    // Extract all fields
    cJSON *device_name_json = cJSON_GetObjectItem(json, "deviceName");
    cJSON *ssid_json = cJSON_GetObjectItem(json, "ssid");
    cJSON *password_json = cJSON_GetObjectItem(json, "wifiPassword");
    cJSON *uuid_json = cJSON_GetObjectItem(json, "userUuid");
    cJSON *user_pass_json = cJSON_GetObjectItem(json, "userPassword");
    cJSON *backend_json = cJSON_GetObjectItem(json, "backendUrl");
    cJSON *broker_json = cJSON_GetObjectItem(json, "brokerUrl");

    // Validate required fields
    if (!cJSON_IsString(device_name_json) || !cJSON_IsString(ssid_json) ||
        !cJSON_IsString(password_json) || !cJSON_IsString(uuid_json) ||
        !cJSON_IsString(user_pass_json) || !cJSON_IsString(backend_json) || 
        !cJSON_IsString(broker_json)) {
        ESP_LOGE(GATTS_TAG, "Missing required fields in JSON");
        send_error_status("Missing required fields");
        cJSON_Delete(json);
        return;
    }

    // Copy values to global variables
    strncpy(device_name, device_name_json->valuestring, sizeof(device_name) - 1);
    strncpy(wifi_ssid, ssid_json->valuestring, sizeof(wifi_ssid) - 1);
    strncpy(wifi_password, password_json->valuestring, sizeof(wifi_password) - 1);
    strncpy(user_uuid, uuid_json->valuestring, sizeof(user_uuid) - 1);
    strncpy(user_password, user_pass_json->valuestring, sizeof(user_password) - 1);
    strncpy(backend_url, backend_json->valuestring, sizeof(backend_url) - 1);
    strncpy(broker_url, broker_json->valuestring, sizeof(broker_url) - 1);

    ESP_LOGI(GATTS_TAG, "Parsed provisioning data:");
    ESP_LOGI(GATTS_TAG, "Device: %s", device_name);
    ESP_LOGI(GATTS_TAG, "SSID: %s", wifi_ssid);
    ESP_LOGI(GATTS_TAG, "User UUID: %s", user_uuid);
    ESP_LOGI(GATTS_TAG, "User Password: %s", strlen(user_password) > 0 ? "[PROVIDED]" : "[EMPTY]");
    ESP_LOGI(GATTS_TAG, "Backend: %s", backend_url);
    ESP_LOGI(GATTS_TAG, "Broker: %s", broker_url);

    cJSON_Delete(json);

    // Get MAC address and start WiFi connection
    get_device_mac_address();
    connect_to_wifi();
}

// --- WiFi event handler ---
static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                              int32_t event_id, void* event_data) {
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        if (s_retry_num < MAX_RETRY) {
            esp_wifi_connect();
            s_retry_num++;
            ESP_LOGI(WIFI_TAG, "retry to connect to the AP");
        } else {
            xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
            wifi_connected = false;
            send_error_status("WiFi connection failed - max retries reached");
        }
        ESP_LOGI(WIFI_TAG, "connect to the AP fail");
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(WIFI_TAG, "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
        s_retry_num = 0;
        wifi_connected = true;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
        
        // Send status update and connect to MQTT
        send_device_status();
        vTaskDelay(pdMS_TO_TICKS(1000)); // Brief delay
        connect_to_mqtt();
    }
}

// --- Connect to WiFi ---
static void connect_to_wifi(void) {
    s_wifi_event_group = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &wifi_event_handler,
                                                        NULL,
                                                        &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &wifi_event_handler,
                                                        NULL,
                                                        &instance_got_ip));

    wifi_config_t wifi_config = {
        .sta = {
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
            .pmf_cfg = {
                .capable = true,
                .required = false
            },
        },
    };
    
    strncpy((char*)wifi_config.sta.ssid, wifi_ssid, sizeof(wifi_config.sta.ssid));
    strncpy((char*)wifi_config.sta.password, wifi_password, sizeof(wifi_config.sta.password));

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(WIFI_TAG, "wifi_init_sta finished.");

    // Wait for connection result
    EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
                                           WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
                                           pdFALSE,
                                           pdFALSE,
                                           portMAX_DELAY);

    if (bits & WIFI_CONNECTED_BIT) {
        ESP_LOGI(WIFI_TAG, "connected to ap SSID:%s", wifi_ssid);
    } else if (bits & WIFI_FAIL_BIT) {
        ESP_LOGI(WIFI_TAG, "Failed to connect to SSID:%s", wifi_ssid);
        send_error_status("WiFi authentication failed");
    } else {
        ESP_LOGE(WIFI_TAG, "UNEXPECTED EVENT");
        send_error_status("WiFi connection timeout");
    }
}

// --- MQTT event handler ---
static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    esp_mqtt_event_handle_t event = event_data;
    esp_mqtt_client_handle_t client = event->client;
    char response_topic[128]; // Declare once at function scope

    switch ((esp_mqtt_event_id_t)event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(MQTT_TAG, "MQTT_EVENT_CONNECTED");
            mqtt_connected = true;
            send_device_status();
            
            // Subscribe to registration response topic
            snprintf(response_topic, sizeof(response_topic), "/%s/devices/register-response", user_uuid);
            int msg_id = esp_mqtt_client_subscribe(client, response_topic, 0);
            ESP_LOGI(MQTT_TAG, "Subscribed to %s, msg_id=%d", response_topic, msg_id);
            
            // Start device registration
            vTaskDelay(pdMS_TO_TICKS(1000)); // Brief delay
            register_device();
            break;

        case MQTT_EVENT_DISCONNECTED:
            ESP_LOGI(MQTT_TAG, "MQTT_EVENT_DISCONNECTED");
            mqtt_connected = false;
            device_registered = false;
            send_device_status();
            break;

        case MQTT_EVENT_DATA:
            ESP_LOGI(MQTT_TAG, "MQTT_EVENT_DATA");
            ESP_LOGI(MQTT_TAG, "TOPIC=%.*s", event->topic_len, event->topic);
            ESP_LOGI(MQTT_TAG, "DATA=%.*s", event->data_len, event->data);
            
            // Check if this is a registration response
            snprintf(response_topic, sizeof(response_topic), "/%s/devices/register-response", user_uuid);
            if (strncmp(event->topic, response_topic, strlen(response_topic)) == 0) {
                // Parse registration response
                cJSON *response = cJSON_ParseWithLength(event->data, event->data_len);
                if (response) {
                    cJSON *status = cJSON_GetObjectItem(response, "status");
                    if (cJSON_IsString(status)) {
                        if (strcmp(status->valuestring, "created") == 0 ||
                            strcmp(status->valuestring, "existing") == 0 ||
                            strcmp(status->valuestring, "reassigned") == 0) {
                            device_registered = true;
                            ESP_LOGI(MQTT_TAG, "Device registration successful: %s", status->valuestring);
                        } else {
                            ESP_LOGE(MQTT_TAG, "Device registration failed: %s", status->valuestring);
                            cJSON *error = cJSON_GetObjectItem(response, "error");
                            if (cJSON_IsString(error)) {
                                send_error_status(error->valuestring);
                            } else {
                                send_error_status("Device registration failed");
                            }
                        }
                    }
                    cJSON_Delete(response);
                }
                send_device_status();
            }
            break;

        case MQTT_EVENT_ERROR:
            ESP_LOGI(MQTT_TAG, "MQTT_EVENT_ERROR");
            mqtt_connected = false;
            send_error_status("MQTT connection error");
            break;

        default:
            ESP_LOGI(MQTT_TAG, "Other event id:%d", event->event_id);
            break;
    }
}

// --- Connect to MQTT ---
static void connect_to_mqtt(void) {
    if (!wifi_connected) {
        ESP_LOGE(MQTT_TAG, "WiFi not connected, cannot start MQTT");
        send_error_status("MQTT failed - no WiFi connection");
        return;
    }

    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = broker_url,
        .credentials.client_id = device_mac,
        .credentials.username = user_uuid,
        .credentials.authentication.password = user_password,
    };

    mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    if (mqtt_client == NULL) {
        ESP_LOGE(MQTT_TAG, "Failed to initialize MQTT client");
        send_error_status("MQTT client initialization failed");
        return;
    }

    esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_err_t err = esp_mqtt_client_start(mqtt_client);
    
    if (err != ESP_OK) {
        ESP_LOGE(MQTT_TAG, "MQTT client start failed: %s", esp_err_to_name(err));
        send_error_status("MQTT client start failed");
    } else {
        ESP_LOGI(MQTT_TAG, "MQTT client started");
    }
}

// --- Register device with backend ---
static void register_device(void) {
    if (!mqtt_connected || mqtt_client == NULL) {
        ESP_LOGE(MQTT_TAG, "MQTT not connected, cannot register device");
        send_error_status("Device registration failed - no MQTT connection");
        return;
    }

    // Create registration message
    cJSON *registration = cJSON_CreateObject();
    cJSON_AddStringToObject(registration, "name", device_name);
    cJSON_AddStringToObject(registration, "macAddress", device_mac);

    char *registration_string = cJSON_Print(registration);
    if (registration_string) {
        char topic[128];
        snprintf(topic, sizeof(topic), "/%s/devices", user_uuid);
        
        int msg_id = esp_mqtt_client_publish(mqtt_client, topic, registration_string, 0, 1, 0);
        ESP_LOGI(MQTT_TAG, "Device registration sent to %s, msg_id=%d", topic, msg_id);
        ESP_LOGI(MQTT_TAG, "Registration data: %s", registration_string);
        
        free(registration_string);
    } else {
        ESP_LOGE(MQTT_TAG, "Failed to serialize registration data");
        send_error_status("Failed to create registration message");
    }
    
    cJSON_Delete(registration);
}

// --- Helper: send response if needed ---
static void example_write_event_env(esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param) {
    if (param->write.need_rsp) {
        esp_ble_gatts_send_response(gatts_if, param->write.conn_id, param->write.trans_id, ESP_GATT_OK, NULL);
    }
}

// --- GAP Event Handler ---
static void gap_event_handler(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
    if (event == ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT || event == ESP_GAP_BLE_SCAN_RSP_DATA_SET_COMPLETE_EVT) {
        esp_ble_gap_start_advertising(&adv_params);
    }
}

// --- GATTS Profile Event Handler ---
static void gatts_profile_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param) {
    switch(event) {
        case ESP_GATTS_REG_EVT: {
            ESP_ERROR_CHECK(esp_ble_gap_set_device_name("ESP32_WIFI_SETUP"));

            profile_tab[0].service_id.is_primary = true;
            profile_tab[0].service_id.id.inst_id = 0x00;
            profile_tab[0].service_id.id.uuid.len = ESP_UUID_LEN_128;
            uint8_t svc_uuid_arr[16] = WIFI_SVC_UUID_128;
            memcpy(profile_tab[0].service_id.id.uuid.uuid.uuid128, svc_uuid_arr, 16);

            esp_ble_gap_config_adv_data(&adv_data);
            esp_ble_gatts_create_service(gatts_if, &profile_tab[0].service_id, WIFI_NUM_HANDLE);
            break;
        }
        case ESP_GATTS_CREATE_EVT: {
            profile_tab[0].service_handle = param->create.service_handle;

            profile_tab[0].char_uuid.len = ESP_UUID_LEN_128;
            uint8_t char_uuid_arr[16] = WIFI_CHAR_UUID_128;
            memcpy(profile_tab[0].char_uuid.uuid.uuid128, char_uuid_arr, 16);

            esp_ble_gatts_start_service(profile_tab[0].service_handle);
            esp_ble_gatts_add_char(profile_tab[0].service_handle, &profile_tab[0].char_uuid,
                                   ESP_GATT_PERM_WRITE | ESP_GATT_PERM_READ, wifi_property, &wifi_attr, NULL);
            break;
        }
        case ESP_GATTS_ADD_CHAR_EVT: {
            profile_tab[0].char_handle = param->add_char.attr_handle;
            notify_handle = param->add_char.attr_handle;
            
            // Add notification descriptor
            esp_bt_uuid_t descr_uuid;
            descr_uuid.len = ESP_UUID_LEN_16;
            descr_uuid.uuid.uuid16 = ESP_GATT_UUID_CHAR_CLIENT_CONFIG;
            
            esp_ble_gatts_add_char_descr(profile_tab[0].service_handle, &descr_uuid,
                                         ESP_GATT_PERM_READ | ESP_GATT_PERM_WRITE, NULL, NULL);
            break;
        }
        case ESP_GATTS_ADD_CHAR_DESCR_EVT: {
            profile_tab[0].descr_handle = param->add_char_descr.attr_handle;
            break;
        }
        case ESP_GATTS_CONNECT_EVT: {
            notify_conn_id = param->connect.conn_id;
            ESP_LOGI(GATTS_TAG, "Client connected, conn_id = %d", notify_conn_id);
            break;
        }
        case ESP_GATTS_DISCONNECT_EVT: {
            esp_ble_gap_start_advertising(&adv_params);
            notify_conn_id = 0;
            notify_enabled = false;
            ESP_LOGI(GATTS_TAG, "Client disconnected, restart advertising");
            break;
        }
        case ESP_GATTS_WRITE_EVT: {
            ESP_LOGI(GATTS_TAG, "WRITE_EVT, handle = %d, value len = %d", param->write.handle, param->write.len);
            
            // Handle notification enable/disable
            if (param->write.handle == profile_tab[0].descr_handle) {
                uint16_t value = *(uint16_t*)param->write.value;
                notify_enabled = (value == 0x0001);
                ESP_LOGI(GATTS_TAG, "Notifications %s", notify_enabled ? "enabled" : "disabled");
                example_write_event_env(gatts_if, param);
                return;
            }
            
            // Handle characteristic write
            if (param->write.handle == profile_tab[0].char_handle) {
                if (param->write.is_prep) {
                    // Prepared write
                    if (!is_prepared_write) {
                        is_prepared_write = true;
                        prepare_write_handle = param->write.handle;
                        provisioning_data_len = 0;
                        memset(provisioning_data, 0, sizeof(provisioning_data));
                    }
                    
                    if (provisioning_data_len + param->write.len <= MAX_PROVISION_DATA) {
                        memcpy(provisioning_data + provisioning_data_len, param->write.value, param->write.len);
                        provisioning_data_len += param->write.len;
                        ESP_LOGI(GATTS_TAG, "Prepared write chunk: %d bytes, total: %d", param->write.len, provisioning_data_len);
                    }
                } else {
                    // Direct write
                    if (param->write.len <= MAX_PROVISION_DATA) {
                        memcpy(provisioning_data, param->write.value, param->write.len);
                        provisioning_data_len = param->write.len;
                        provisioning_data[provisioning_data_len] = '\0';
                        ESP_LOGI(GATTS_TAG, "Direct write complete: %d bytes", param->write.len);
                        ESP_LOGI(GATTS_TAG, "Received data: %s", provisioning_data);
                        parse_provisioning_data((char*)provisioning_data);
                    }
                }
            }
            
            example_write_event_env(gatts_if, param);
            break;
        }
        case ESP_GATTS_EXEC_WRITE_EVT: {
            ESP_LOGI(GATTS_TAG, "EXEC_WRITE_EVT, exec_write_flag = %s", param->exec_write.exec_write_flag ? "EXECUTE" : "CANCEL");
            
            if (param->exec_write.exec_write_flag && is_prepared_write && provisioning_data_len > 0) {
                provisioning_data[provisioning_data_len] = '\0';
                ESP_LOGI(GATTS_TAG, "Prepared write complete: %d bytes", provisioning_data_len);
                ESP_LOGI(GATTS_TAG, "Complete data: %s", provisioning_data);
                parse_provisioning_data((char*)provisioning_data);
            }
            
            // Reset prepared write state
            is_prepared_write = false;
            prepare_write_handle = 0;
            
            // Always send response for exec_write
            esp_ble_gatts_send_response(gatts_if, param->exec_write.conn_id, param->exec_write.trans_id, ESP_GATT_OK, NULL);
            break;
        }
        default:
            break;
    }
}

// --- GATTS Event Handler ---
static void gatts_event_handler(esp_gatts_cb_event_t event, esp_gatt_if_t gatts_if, esp_ble_gatts_cb_param_t *param) {
    if (event == ESP_GATTS_REG_EVT && param->reg.status == ESP_GATT_OK) {
        profile_tab[param->reg.app_id].gatts_if = gatts_if;
    }

    if (profile_tab[0].gatts_cb) {
        profile_tab[0].gatts_cb(event, gatts_if, param);
    }
}

// --- app_main ---
void app_main(void) {
    esp_err_t ret;

    // Initialize NVS
    ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // Initialize Bluetooth
    ESP_ERROR_CHECK(esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT));

    esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_bt_controller_init(&bt_cfg));
    ESP_ERROR_CHECK(esp_bt_controller_enable(ESP_BT_MODE_BLE));
    ESP_ERROR_CHECK(esp_bluedroid_init());
    ESP_ERROR_CHECK(esp_bluedroid_enable());

    // Set MTU for larger data transfers
    esp_err_t mtu_ret = esp_ble_gatt_set_local_mtu(MAX_PROVISION_DATA);
    if (mtu_ret) {
        ESP_LOGE(GATTS_TAG, "Set local MTU failed: %d", mtu_ret);
    }

    // Register BLE callbacks and start service
    ESP_ERROR_CHECK(esp_ble_gap_register_callback(gap_event_handler));
    ESP_ERROR_CHECK(esp_ble_gatts_register_callback(gatts_event_handler));
    profile_tab[0].gatts_cb = gatts_profile_event_handler;
    ESP_ERROR_CHECK(esp_ble_gatts_app_register(PROFILE_APP_ID));

    ESP_LOGI(GATTS_TAG, "BLE WiFi Provisioning Server Started");
}