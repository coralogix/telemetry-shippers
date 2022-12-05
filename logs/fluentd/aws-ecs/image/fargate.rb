def start
  super
  # This is the first method to be called when it starts running
  # Use it to allocate resources, etc.
  require 'json'
  # get docker metadata file
  `curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task > /var/log/docker-metadata.json`
  # create cache
  @metadata_cache = {}
  # populate cache
  json = JSON.parse(File.read('/var/log/docker-metadata.json'))
  json['Containers'].each do |container|
    docker_id = container['DockerId']
    @metadata_cache[docker_id] = container
  end
end

def shutdown
  super
  # This method is called when Fluentd is shutting down.
  # Use it to free up resources, etc.
  @metadata_cache = nil
end

def filter(tag, time, record)
  # This method implements the filtering logic for individual filters
  # Get docker id
  if record.key?('container_id') then
    docker_id = record['container_id']
    metadata = @metadata_cache[docker_id]
    if metadata != nil then
      # Create the docker field
      record['docker'] = {
        'id' => metadata['DockerId'],
        'name' => metadata['Name'],
        'container_hostname' => metadata['DockerName'],
        'image' => metadata['Image'],
        'image_id' => metadata['ImageID'],
        'labels' => metadata['Labels']
      }
      record.delete('ecs_task_arn')
      record.delete('ecs_task_definition')
      record.delete('container_name')
      record.delete('container_id')
    else
      log.warn('could not find docker id ' + docker_id + ' inside docker metadata cache')
    end
  end
  return record
end
