idf_component_register(
    SRCS "main.cpp"
    INCLUDE_DIRS "."
    REQUIRES driver soc esp_adc esp_timer nvs_flash bt
)
