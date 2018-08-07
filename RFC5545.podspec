Pod::Spec.new do |s|

  s.name         = "RFC5545"
  s.version      = "1.1.0"
  s.summary      = "Convert between RFC5545 and iOS' EKEvent class."

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  s.description  = <<-DESC
Converts back and forth between RFC5545 specification (iCalendar/.ics) and Apple's EKEvent structure.
                   DESC

  s.homepage     = "https://github.com/GargoyleSoft/RFC5545"

  s.license      = { :type => "MIT", :file => 'LICENSE' }

  s.author             = { "Gargoyle Software, LLC" => "" }

  s.platform     = :ios, "9.0"

  #  When using multiple platforms
  # s.ios.deployment_target = "5.0"
  # s.osx.deployment_target = "10.7"
  # s.watchos.deployment_target = "2.0"
  # s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/GargoyleSoft/RFC5545.git", :tag => "v#{s.version}" }

  s.source_files  = "RFC5545"
end
