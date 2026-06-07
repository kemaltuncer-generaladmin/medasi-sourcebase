#!/usr/bin/env ruby
# Regenerates App/SourceBase.xcodeproj (deleted). Single iOS app target that
# embeds the local SwiftPM package SourceBaseiOS (which path-depends on
# SourceBaseBackend). Mirrors the hand-built App Store project.
require 'xcodeproj'

APP_DIR   = File.expand_path(File.dirname(__FILE__))      # .../swiftsourcebase/App
PROJ_PATH = File.join(APP_DIR, 'SourceBase.xcodeproj')
TEAM_ID   = '489N9D2VTC'
BUILD_NUM = '49'   # bump for each App Store Connect upload

FileUtils.rm_rf(PROJ_PATH) if File.exist?(PROJ_PATH)
project = Xcodeproj::Project.new(PROJ_PATH)
project.build_configuration_list.build_configurations.each do |c|
  c.build_settings['SDKROOT'] = 'iphoneos'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['ALWAYS_SEARCH_USER_PATHS'] = 'NO'
  c.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  c.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
  c.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  c.build_settings['ENABLE_STRICT_OBJC_MSGSEND'] = 'YES'
  c.build_settings['GCC_NO_COMMON_BLOCKS'] = 'YES'
  c.build_settings['SWIFT_COMPILATION_MODE'] = (c.name == 'Release' ? 'wholemodule' : 'singlefile')
  c.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = (c.name == 'Release' ? '-O' : '-Onone')
  c.build_settings['ONLY_ACTIVE_ARCH'] = (c.name == 'Release' ? 'NO' : 'YES')
  c.build_settings['ENABLE_TESTABILITY'] = (c.name == 'Release' ? 'NO' : 'YES')
  c.build_settings['COPY_PHASE_STRIP'] = 'NO'
  c.build_settings['DEBUG_INFORMATION_FORMAT'] = (c.name == 'Release' ? 'dwarf-with-dsym' : 'dwarf')
end

target = project.new_target(:application, 'SourceBase', :ios, '17.0')

# ---- Files ----
app_group = project.main_group.new_group('SourceBase', 'SourceBase')
main_swift = app_group.new_reference('SourceBaseAppMain.swift')
assets     = app_group.new_reference('Assets.xcassets')
privacy    = app_group.new_reference('PrivacyInfo.xcprivacy')
app_group.new_reference('Info.plist')
app_group.new_reference('SourceBase.entitlements')

target.source_build_phase.add_file_reference(main_swift)
target.resources_build_phase.add_file_reference(assets)
target.resources_build_phase.add_file_reference(privacy)

# ---- Local SwiftPM package (SourceBaseiOS) ----
ios_pkg = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
ios_pkg.relative_path = '../SourceBaseiOS'
project.root_object.package_references ||= []
project.root_object.package_references << ios_pkg

dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dep.product_name = 'SourceBaseiOS'
dep.package = ios_pkg
target.package_product_dependencies << dep

link = project.new(Xcodeproj::Project::Object::PBXBuildFile)
link.product_ref = dep
target.frameworks_build_phase.files << link

# ---- Build settings (target) ----
target.build_configurations.each do |c|
  bs = c.build_settings
  bs['PRODUCT_NAME'] = 'SourceBase'
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'tr.com.medasi.sourcebase'
  bs['MARKETING_VERSION'] = '1.0.0'
  bs['CURRENT_PROJECT_VERSION'] = BUILD_NUM
  bs['INFOPLIST_FILE'] = 'SourceBase/Info.plist'
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['CODE_SIGN_ENTITLEMENTS'] = 'SourceBase/SourceBase.entitlements'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = TEAM_ID
  bs['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SWIFT_VERSION'] = '5.0'
  bs['ENABLE_PREVIEWS'] = 'YES'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  bs['CLANG_ANALYZER_NONNULL'] = 'YES'
  bs['SUPPORTS_MACCATALYST'] = 'NO'
  bs['SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'] = 'NO'
end

project.save

# ---- Shared scheme so `xcodebuild -scheme SourceBase` works ----
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(PROJ_PATH, 'SourceBase', true)

puts "OK: regenerated #{PROJ_PATH} (build #{BUILD_NUM})"
