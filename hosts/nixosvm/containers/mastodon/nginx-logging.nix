{
  services.nginx.commonHttpConfig = ''
    # omit success (and redirect) in logs unless they generate an absurd amount of load
    map $status,$request_time $loggable {
      ~,[^0]  1;  # slow
      ~^[23]  0;  # successful (or redirect, not modified, etc)
      401 0;      # unauthorized, not unusual because we have pw auth
      default 1;  # some unusual status
    }
    log_format mini '[$time_iso8601] $status $request_method "$host$uri" rt=$request_time';

    access_log /var/log/nginx/access.log mini if=$loggable;
  '';
}
