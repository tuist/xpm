# frozen_string_literal: true
require 'minitest/assertions'
require 'xcodeproj'
require 'simctl'

module Xcode
  include Minitest::Assertions

  def self.workspace(workspace_path)
    Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
  end

  def self.projects(workspace_path)
    workspace(workspace_path)
      .file_references
      .filter { |f| f.path.include?(".xcodeproj") }
      .map { |f| File.join(File.dirname(workspace_path), f.path)}
      .map { |p| Xcodeproj::Project.open(p) }
  end

  def self.product_with_name(name, destination:, derived_data_path:)
    glob = File.join(derived_data_path, "**/Build/**/Products/#{destination}/#{name}/")
    Dir.glob(glob).max_by { |f| File.mtime(f) }
  end

  def self.find_framework(product:, destination:, framework:, derived_data_path:)
    product_path = product_with_name(
      product,
      destination: destination,
      derived_data_path: derived_data_path
    )

    return if product_path.nil?

    framework_glob = File.join(product_path, "**/Frameworks/#{framework}.framework")
    # /path/to/product/Frameworks/MyFramework.framework
    framework_path = Dir.glob(framework_glob).first

    framework_path
  end

  def self.find_resource(product:, destination:, resource:, derived_data_path:)
    product_path = product_with_name(
      product,
      destination: destination,
      derived_data_path: derived_data_path
    )
    return if product_path.nil?

    resource_glob = File.join(product_path, "**/#{resource}")
    # /path/to/product/resource.png
    Dir.glob(resource_glob).first
  end

  def self.find_extension(product:, destination:, extension:, derived_data_path:)
    product_path = product_with_name(
      product,
      destination: destination,
      derived_data_path: derived_data_path
    )

    return if product_path.nil?

    extension_glob = File.join(product_path, "Plugins/#{extension}.appex")
    # /path/to/product/Plugins/MyExtension.appex
    extension_path = Dir.glob(extension_glob).first

    extension_path
  end

  def self.find_headers(product:, destination:, derived_data_path:)
    product_path = product_with_name(
      product,
      destination: destination,
      derived_data_path: derived_data_path
    )
    return if product_path.nil?

    headers_glob = File.join(product_path, "**/*.h")
    # /path/to/product/header.h
    Dir.glob(headers_glob)
  end

  def self.valid_simulator_destination_for_platform(platform)
    device = SimCtl
      .list_devices
      .select { |d| d.is_available && d.runtime.name.downcase.include?(platform.downcase) }
      .sort { |l, r| l.runtime.version <=> r.runtime.version }
      .last

    if device.nil?
      flunk("Couldn't find an available destination simulator for platform #{platform}")
    end
    "platform=#{platform} Simulator,id=#{device.udid}"
  end
end
