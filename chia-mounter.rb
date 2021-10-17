#!/usr/bin/env ruby

mount_dir = '/mnt'
mount_name_base = 'chia-plots-'

# find all drives
all_block_devs =
  `lsblk --noheadings --nodeps --output NAME,MODEL,SERIAL,ROTA`.split(/\n/)

devs =
  all_block_devs
    .map do |dev|
      name, model, serial, rotational = dev.strip.split(/ +/)

      interface =
        case name
        when /^s/
          'ata'
        when /^nvme/
          'nvme'
        else
          'unknown_interface'
        end

      {
        path: "/dev/disk/by-id/#{interface}-#{model}_#{serial}-part1",
        ssd: rotational.to_i == 0
      }
    end
    .select do |dev|
      # check if drive is for chia
      puts "Checking dev #{dev[:path]}"
      label = `btrfs fi label "#{dev[:path]}"`
      !(label =~ /chia/).nil?
    end
    .sort do |a, b|
      # sort drives by SSD
      b[:ssd] ? 1 : 0 <=> a[:ssd] ? 1 : 0
    end

puts devs

# mount drives
devs.each_with_index do |dev, i|
  puts "Mounting #{dev[:path]}"
  out = `mount "#{dev[:path]}" "#{mount_dir}/#{mount_name_base}#{'%02d' % i}"`
  if out.strip != ''
    puts out
  end
end
