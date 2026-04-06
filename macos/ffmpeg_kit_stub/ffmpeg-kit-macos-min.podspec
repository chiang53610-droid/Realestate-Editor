Pod::Spec.new do |s|
  s.name             = 'ffmpeg-kit-macos-min'
  s.version          = '6.0'
  s.summary          = 'Local stub for macOS desktop development (FFmpeg not needed on macOS)'
  s.homepage         = 'https://github.com/arthenica/ffmpeg-kit'
  s.license          = { :type => 'LGPL-3.0' }
  s.author           = { 'stub' => 'stub@stub.com' }
  s.source           = { :path => '.' }
  s.osx.deployment_target = '11.0'

  s.source_files     = 'ffmpegkit/**/*.{h,m}'
  s.public_header_files = 'ffmpegkit/**/*.h'
  s.header_dir       = 'ffmpegkit'
  s.module_name      = 'ffmpegkit'
end
