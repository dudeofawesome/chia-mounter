#!/usr/bin/env ruby

require 'json'

mount_dir = '/mnt'
mount_name_base = 'chia-plots-'

# find all drives
all_block_devs =
  JSON.parse(`lsblk --json --output NAME,LABEL,MODEL,SERIAL,ROTA,MOUNTPOINT`)

devs =
  all_block_devs['blockdevices']
    .select do |dev|
      # check if partition has chia label
      false if dev['children'].nil?
      dev['children'].any? { |part| !(part['label'] =~ /chia/).nil? }
    end
    .map do |dev|
      # transform data
      interface =
        case dev['name']
        when /^s/
          'ata'
        when /^nvme/
          'nvme'
        else
          'unknown_interface'
        end

      name = "#{interface}-#{dev['model']}_#{dev['serial']}".gsub(/ /, '_')
      partition =
        dev['children'].find_index { |part| !(part['label'] =~ /chia/).nil? }

      {
        path: "/dev/disk/by-id/#{name}-part#{partition + 1}",
        mountpoint: dev['children'][partition]['mountpoint'],
        mountpoint_num:
          (dev['children'][partition]['mountpoint'].match(/\d+$/) || [])[0]
            &.to_i,
        ssd: !dev['rota'],
      }
    end
    .sort do |a, b|
      # sort drives by SSD
      b[:ssd] ? 1 : 0 <=> a[:ssd] ? 1 : 0
    end

devs_to_mount = devs.select { |dev| dev[:mountpoint].nil? }
mounted_devs = devs.select { |dev| !dev[:mountpoint].nil? }

starting_index =
  mounted_devs.max do |a, b|
    (a[:mountpoint_num] || 0) <=> (b[:mountpoint_num] || 0)
  end[
    :mountpoint_num
  ]

# mount drives
devs_to_mount.each_with_index do |dev, i|
  puts "Mounting #{dev[:path]}"

  mountpoint =
    File.join(mount_dir, "#{mount_name_base}#{'%02d' % (i + starting_index)}")

  Dir.mkdir(mountpoint) if !File.exist?(mountpoint)

  out = `mount "#{dev[:path]}" "#{mountpoint}"`
  puts out if out.strip != ''
end
