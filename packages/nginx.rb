class Nginx < PACKMAN::Package
  url 'http://nginx.org/download/nginx-1.9.3.tar.gz'
  sha1 '7f91765af249ad14a5f5159b587113e4345b74a5'
  version '1.9.3'

  label :compiler_insensitive

  # Start options.
  option :user => 'nobody'
  option :group => 'nogroup'
  option :worker_processes => 'auto'
  option :worker_connections => 1024
  option :port => 8080
  option :with_passenger => false

  depends_on :pcre
  depends_on :zlib
  depends_on :openssl
  depends_on :passenger if with_passenger?

  def self.conf; Nginx.etc+'/nginx/nginx.conf'; end

  def install
    PACKMAN.replace 'conf/nginx.conf', {
      'listen       80;' => "listen       #{port};",
      /(http {.*)}/m => "\\1\n    include servers/*;\n}"
    }
    PACKMAN.replace 'auto/lib/pcre/conf', '/usr/local' => link_root
    PACKMAN.replace 'auto/lib/openssl/conf', '/usr/local' => Openssl.prefix
    PACKMAN.handle_unlinked Openssl, :use_cflags
    PACKMAN.replace 'auto/lib/zlib/conf', {
      'ngx_feature_libs="-lz"' => "ngx_feature_inc_path='-I#{Zlib_.inc}'\nngx_feature_libs='-L#{Zlib_.lib} -lz'"
    }
    args = %W[
      --prefix=#{prefix}
      --with-http_ssl_module
      --with-pcre
      --with-ipv6
      --sbin-path=#{bin}/nginx
      --conf-path=#{etc}/nginx/nginx.conf
      --pid-path=#{var}/run/nginx.pid
      --lock-path=#{var}/run/nginx.lock
      --http-client-body-temp-path=#{var}/run/nginx/client_body_temp
      --http-proxy-temp-path=#{var}/run/nginx/proxy_temp
      --http-fastcgi-temp-path=#{var}/run/nginx/fastcgi_temp
      --http-uwsgi-temp-path=#{var}/run/nginx/uwsgi_temp
      --http-scgi-temp-path=#{var}/run/nginx/scgi_temp
      --http-log-path=#{var}/log/nginx/access.log
      --error-log-path=#{var}/log/nginx/error.log
      --with-http_gzip_static_module
      --with-http_dav_module
      --with-http_spdy_module
      --with-http_gunzip_module
    ]
    if with_passenger?
      nginx_ext = `#{Passenger.bin}/passenger-config --nginx-addon-dir`.chomp
      args << "--add-module=#{nginx_ext}"
    end
    PACKMAN.run './configure', *args
    PACKMAN.replace './objs/Makefile', /LINK\s*=\s*(.*)/ => "LINK = \\1 $(LDFLAGS)"
    PACKMAN.run 'make -j2'
    PACKMAN.run 'make install'
    PACKMAN.report_notice "Default listen port is #{PACKMAN.red port}."
    PACKMAN.mkdir etc+'/nginx/servers', :skip_if_exist
    PACKMAN.mkdir var+'/run/nginx', :skip_if_exist
    PACKMAN.mkdir man+'/man8', :skip_if_exist
    PACKMAN.cp 'man/nginx.8', man+'/man8'
  end

  def post_install
    if with_passenger?
      conf = etc+'/nginx/nginx.conf'
      root = `#{Passenger.bin+'/passenger-config'} --root`.chomp
      if File.new(conf).read.include? root
        PACKMAN.report_error "#{PACKMAN.red conf} contains #{root}!"
      end
      PACKMAN.replace conf, {
        /(http {.*)}/m => "\\1\n    passenger_root #{root};\n    passenger_ruby #{Ruby.bin+'/ruby'};\n}"
      }
    end
  end

  def start options = {}
    return if status
    PACKMAN.replace etc+'/nginx/nginx.conf', {
      /worker_processes.*/ => "worker_processes #{worker_processes};",
      /worker_connections.*/ => "worker_connections #{worker_connections};"
    }
    res = PACKMAN.run bin+'/nginx', :skip_error, :return_output
    if not $?.success?
      if res =~ /Permission denied/
        PACKMAN.report_warning "You need root privilege to start #{PACKMAN.green 'nginx'}!"
        PACKMAN.run "sudo #{bin}/nginx", :screen_output
      end
    end
  end

  def status
    PACKMAN.is_process_running? `cat #{var}/run/nginx.pid` if File.exist? "#{var}/run/nginx.pid"
  end

  def stop
    res = PACKMAN.run bin+'/nginx -s stop', :skip_error, :return_output
    if not $?.success?
      if res =~ /Operation not permitted/
        PACKMAN.report_warning "You need root privilege to stop #{PACKMAN.green 'nginx'}!"
        PACKMAN.run "sudo #{bin}/nginx -s stop", :screen_output
      end
    end
  end
end
