Pod::Spec.new do |s|
  s.name             = 'cupertino_fundations_models'
  s.version          = '0.0.1'
  s.summary          = 'Flutter bridge for Apple Foundation Models.'
  s.description      = 'A native Flutter plugin for Apple Foundation Models, Private Cloud Compute capabilities, structured generation, and tool calling.'
  s.homepage         = 'https://github.com/sooyvilla/cupertino_fundations_models'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sebastian Villa' => 'sooyvilla' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
