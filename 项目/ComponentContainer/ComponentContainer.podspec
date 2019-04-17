Pod::Spec.new do |s|
  s.name         = "ComponentContainer" 
  s.version      = "0.3"        
  s.summary      = "腾讯新闻iOS基础架构 —— 高性能、易扩展、组件化的Hybrid资讯内容页解决方案。"
  s.homepage     = "https://git.code.oa.com/QQNews_iOS/ComponentContainer"
  s.license      = "MIT"
  s.author       = "dequanzhu"
  s.platform     = :ios, "8.0"
  s.requires_arc = true
  s.source       = { :git => "http://git.code.oa.com/QQNews_iOS/ComponentContainer.git", :tag => s.version.to_s }
  s.source_files = "ComponentContainer/ComponentContainer/ComponentContainer/**/*.{h,m}"
  s.public_header_files = "ComponentContainer/ComponentContainer/ComponentContainer/*.{h,m}"

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = "ComponentContainer/ComponentContainer/ComponentContainerTests/*.{h,m}"
  end  
end
