#!/usr/bin/env ruby
# Reproducible Xcode project; requires the development-only xcodeproj gem.
require 'xcodeproj'
require 'pathname'

root = Pathname.new(__dir__).parent.join('ios')
path = root.join('Leanora.xcodeproj')
project = Xcodeproj::Project.new(path)
project.root_object.attributes['LastUpgradeCheck'] = '2700'
project.root_object.development_region = 'zh-Hans'
project.root_object.known_regions = ['zh-Hans', 'en', 'Base']
app = project.new_target(:application, 'Leanora', :ios, '18.0')
unit = project.new_target(:unit_test_bundle, 'LeanoraTests', :ios, '18.0')
ui = project.new_target(:ui_test_bundle, 'LeanoraUITests', :ios, '18.0')
unit.add_dependency(app)
ui.add_dependency(app)

[app, unit, ui].each do |target|
  target.build_configurations.each do |config|
    config.build_settings.merge!({
      'SWIFT_VERSION' => '6.0',
      'IPHONEOS_DEPLOYMENT_TARGET' => '18.0',
      'TARGETED_DEVICE_FAMILY' => '1',
      'CODE_SIGN_STYLE' => 'Automatic',
      'DEVELOPMENT_TEAM' => '8ZP3NMT2A8', # Manyao Li; verified in local Xcode and public certificate OU.
      'GENERATE_INFOPLIST_FILE' => 'YES',
      'PRODUCT_BUNDLE_IDENTIFIER' => "ai.leanora.fitness#{target == app ? '' : '.' + target.name}",
      'MARKETING_VERSION' => '1.0',
      'CURRENT_PROJECT_VERSION' => '3',
      'SWIFT_EMIT_LOC_STRINGS' => 'YES',
      'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES'
    })
  end
end
app.build_configurations.each do |config|
  config.build_settings.merge!({
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => 'Leanora/Resources/Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => 'Leanora/Leanora.entitlements',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon'
  })
end
unit.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Leanora.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Leanora'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
ui.build_configurations.each { |config| config.build_settings['TEST_TARGET_NAME'] = 'Leanora' }
project.root_object.attributes['TargetAttributes'] = {
  app.uuid => {'SystemCapabilities' => {'com.apple.HealthKit' => {'enabled' => 1}}}
}

[[app, 'Leanora'], [unit, 'LeanoraTests'], [ui, 'LeanoraUITests']].each do |target, folder|
  group = project.main_group.new_group(folder, folder)
  Dir.glob(root.join(folder, '**', '*').to_s).sort.each do |file|
    next if File.directory?(file)
    relative = Pathname.new(file).relative_path_from(root.join(folder)).to_s
    next if relative.include?('.xcassets/')
    reference = group.new_file(relative)
    if File.extname(file) == '.swift'
      target.source_build_phase.add_file_reference(reference)
    elsif ['.xcstrings', '.xcprivacy', '.json'].include?(File.extname(file))
      target.resources_build_phase.add_file_reference(reference)
    end
  end
  Dir.glob(root.join(folder, '**', '*.xcassets').to_s).each do |asset|
    reference = group.new_file(Pathname.new(asset).relative_path_from(root.join(folder)).to_s)
    target.resources_build_phase.add_file_reference(reference)
  end
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.add_test_target(unit)
scheme.add_test_target(ui)
scheme.test_action.build_configuration = 'Debug'
scheme.test_action.code_coverage_enabled = true
scheme.save_as(path, 'Leanora', true)
puts "Generated #{path}"
