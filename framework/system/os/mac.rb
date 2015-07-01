module PACKMAN
  class Mac < Os
    vendor :Apple
    type :Mac_OS_X
    check :version do
      `sw_vers`.match(/ProductVersion:\s*(\d+\.\d+\.\d+)/)[1]
    end
    package_manager :Homebrew, {
      :query_command => 'brew list',
      :install_command => 'brew install'
    }
    check :Xcode do
      PACKMAN.does_command_exist? 'xcode-select'
    end
    check :CommandLineTools do
      if version >= '10.9'
        `pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>&1`
      elsif version >= '10.8'
        `pkgutil --pkg-info=com.apple.pkg.DeveloperToolsCLI 2>&1`
      end
      $?.success?
    end
    command :check_user do |name|
      res = `id -u #{name} 2>&1`
      $?.success?
    end
  end
end
