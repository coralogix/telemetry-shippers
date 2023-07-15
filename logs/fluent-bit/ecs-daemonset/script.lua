RETURN_WITHOUT_MODIFYING_TIMESTAMP = 2
function addcrxmetadata(tag, timestamp, record)
    new_record = record

    -- Prioritize environment variables first
    local env_app_name = os.getenv("APP_NAME")
    local env_sub_system = os.getenv("SUB_SYSTEM")

    if env_app_name then
        new_record["applicationName"] = env_app_name
    elseif record.json and record.json.clusterName then
        new_record["applicationName"] = record.json.clusterName
    else
        new_record["applicationName"] = "no-application"
    end

    if env_sub_system then
        new_record["subsystemName"] = env_sub_system
    elseif record.json.ECSContainerName then
        new_record["subsystemName"] = record.json.ECSContainerName
    else
        new_record["subsystemName"] = "no-subsystem"
    end

    local processed_fraction = string.format("%09d", timestamp['nsec'])
    new_record["timestamp"] = string.format("%s%s", timestamp['sec'], string.sub(processed_fraction, 1, -4))
    return RETURN_WITHOUT_MODIFYING_TIMESTAMP, timestamp, new_record
end
