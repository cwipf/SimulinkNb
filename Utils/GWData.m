classdef GWData < handle
  % -- GWData --
  % A GWData (Gravitational Wave Data) object stores state information
  % about recent data fetching activity.
  %
  % Methods:
  %  - Methods for getting data:
  %     <a href="matlab:help GWdata.fetch">fetch</a> - fetch data from NDS
  %
  %  - Static Methods for GPS time conversion:
  %     <a href="matlab:help GWdata.gps_time">gps_time</a> - get GPS time now, or at some specified time
  %     <a href="matlab:help GWdata.gps_to_datenum">gps_to_datenum</a> - convert GPS time now to Matlab date number
  %
  %  - Static Methods for Kerberos Authentication:
  %     <a href="matlab:help GWdata.make_kerberos_ready">make_kerberos_ready</a> - check Kerberos ticket status (with is_kerberos_ready) and call kinit if needed
  %
  % How to install:
  %  - GWData requires the nds2-client library. Downloads and instructions
  %    for setting up nds2-client are found here:
  %    <a href="https://trac.ligo.caltech.edu/nds2">https://trac.ligo.caltech.edu/nds2</a>
  %
  %  - After you have nds2-client, add it to Matlab's java path:
  %    * Run this command in a terminal window to find out where
  %      nds2-client's java component was installed:
  %      $ nds-client-config --javaclasspath
  %
  %    * Then create (or edit) the file "javaclasspath.txt" in your Matlab
  %      startup folder. Paste the nds2-client path as a line in the file.
  %
  %  - Note: if nds2-client is found but not in the path, GWData tries to
  %    update the path to include it. This lets you use GWData, but it may
  %    have unintended effects on your Matlab environment, such as clearing
  %    persistent variables, breakpoints, etc. (See "doc javaaddpath" for
  %    more details.) Adding nds2-client to the predefined java path avoids
  %    these side effects.
  %
  % by Matthew Evans and Chris Wipf, January 2015
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Properties
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  properties (SetAccess = public)
    % maximum NDS request size
    nds_max_chans = 100;

    % configure prefered servers for each site (set in constructor)
    site_info = struct('name', [], 'server', [], 'port', 31200);
    server_info = struct('server', [], 'port', 31200);
    site_list = {};
    
    % Kerberos
    kerb_path = '';         % path to Kerberos (kinit and klist)
    kerb_srv = 'LIGO.ORG';  % Kerberos service principal
  end
  
  properties (SetAccess = protected)
    % state information
    last_start_time = [];
    last_end_time = [];
    last_channel_list = {};
    
    % Kerberos
    kerb_is_ready = false;
    kerb_end_time = 0;
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Static Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods (Static)
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GPS Times
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function t = gps_time(varargin)
      % t = gps_time
      %   get GPS seconds, with sub-second precision
      %   (see also gps_to_datenum, tzconvert)
      %
      % if an argument is given, it is used instead of "now"
      % (see now, datenum, datevec, etc.)
      %
      % % Example:
      % t_now = GWData.gps_time
      %
      % % Example:
      % t_dec3 = GWData.gps_time('3 Dec 2014 13:00:10')
      %
      % % Exmaple, using GWData.tzconvert:
      % t0 = GWData.gps_time('06 Jan 1980 00:00:00 GMT')
      %
      % % Example, using full datenum format string:
      % tLeapA = GWData.gps_time('Jan 01 00:00:00 GMT 2009', 'mmm dd HH:MM:SS zzz yyyy')
      % tLeapB = GWData.gps_time({'Jan 01 00:00:01 GMT 2009', 'mmm dd HH:MM:SS zzz yyyy'})
      %
      % % Example: consistency check!
      % datestr(GWData.gps_to_datenum(GWData.gps_time('3 Dec 2014 13:00:10')))
      
      if nargin == 0
        % use current time
        dn = now;
      else
        % convert strings or other things to a date number
        if nargin == 1 && isscalar(varargin{1})
          dn = varargin{1};
        elseif nargin == 1 && ischar(varargin{1})
          dn = GWData.tzconvert(varargin{1});
        elseif nargin == 1 && iscell(varargin{1})
          dn = datenum(varargin{1}{:});
        else
          dn = datenum(varargin{:});
        end
      end
      
      % convert date number to GPS time
      t = GWData.datenum_to_gps(dn);
    end    
    function t = gps_convert(userGPS, anchorGPS, isAfter, pivotGPS)
      % t = gps_convert(userGPS, anchorGPS, isAfter, pivotGPS)
      %   convert a user specified time into a GPS value
      %
      %   userGPS = time specified by user
      %             If userGPS is a string, vector, or cell array, it is
      %             passed to datenum for conversion.  Note, datenum uses
      %             local time, not UTC (see datenum for more information).
      %
      %   anchorGPS = if user time is relative, this is the absolute referece
      %               (the default is the current GPS)
      %
      %   pivotGPS = numerical GPS values less than this are considered to
      %              be relative, larger values (corresponding to later times)
      %              are considered absolute.
      %                The default is January 1, 2000 (GPS 630730000).
      %
      %   isAfter = relative time is after anchor time?  If true
      %             tGPS = anchorGPS + userGPS.  Else relative time
      %             is before anchor (e.g., tGPS = anchorGPS - userGPS).
      %             (default is false)
      %
      %    t = userGPS converted to GPS second
      %
      % Example: GPS second for 3 Dec 2014 13:00:10
      % t = gps_convert('3 Dec 2014 13:00:10');
      %
      % Example: 100 seconds BEFORE the current time.
      % t = gps_convert(100);
      %
      % Example: 100 seconds AFTER 3 Dec 2014 13:00:10.
      % t = gps_convert(100, '3 Dec 2014 13:00:10', true);
      %
      % Example: 100 seconds BEFORE 3 Dec 2014 13:00:10 GMT
      % t = gps_convert(100, {'2014 Dec 03 13:00:10 GMT', 'yyyy mmm dd HH:MM:SS zzz'});
      
      % deal with arguments
      if nargin < 4
        pivotGPS = 630730000;
      end
      if nargin < 3
        isAfter = false;
      end
      if nargin < 2
        anchorGPS = GWData.gps_time();
      end
      
      % convert all GPS times to scalars
      if ~isscalar(userGPS)
        userGPS = GWData.gps_time(userGPS);
      end
      if ~isscalar(anchorGPS)
        anchorGPS = GWData.gps_time(anchorGPS);
      end
      if ~isscalar(pivotGPS)
        pivotGPS = GWData.gps_time(pivotGPS);
      end
      
      % check for relativity
      if userGPS >= pivotGPS
        t = userGPS;
      else
        if isAfter
          t = anchorGPS + userGPS;
        else
          t = anchorGPS - userGPS;
        end
      end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Time Standards
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function t = gps_to_datenum(t_gps)
      % t = gps_to_datenum(gpsTime)
      %   Converts GPS second to a local matlab date number
      %   (see also gps_time, gps_to_unix, unix_to_datenum)
      
      t = GWData.unix_to_datenum(GWData.gps_to_unix(t_gps));
    end
    function t = datenum_to_gps(dn)
      % t = gps_to_datenum(gpsTime)
      %   Converts local matlab date number to GPS second
      %   (see also gps_time, datenum_to_unix, unix_to_gps)
      
      t = GWData.unix_to_gps(GWData.datenum_to_unix(dn));
    end
    function t = datenum_to_unix(dn)
      % t = datenum_to_unix(gpsTime)
      %   Converts local matlab date number to UNIX time
      %   (see also gps_time, datenum_to_unix, unix_to_gps)
      
      % use matlab date number (note that milliseconds are lost
      % when making javaDate, and added back in later)
      [y, m, d, h, mn, s] = datevec(dn);
      javaDate = java.util.Date(y - 1900, m - 1, d, h, mn, floor(s));
      
      % UNIX time, noting that java time is in milliseconds
      % and that we lost some milliseconds when creating the javaDate
      t = javaDate.getTime / 1000 + (s - floor(s));
    end
    function dn = unix_to_datenum(t_unix)
      % t = unix_to_datenum(gpsTime)
      %   Converts UNIX time to local matlab date number
      %   (see also gps_time, datenum_to_unix, unix_to_gps)
      
      % This is trickier than it looks!
      % Note that the datenum is not continuous across daylight savings
      % changes, while UNIX time is, so the following does not work:
      %  localOffset = datenum('Jan 01 1970 GMT', 'mmm dd yyyy zzz');
      %  t = (t_unix / 86400) + localOffset;
      
      % go back to datenum through java, reversing datenum_to_unix
      javaDate = java.util.Date(t_unix * 1000);
      cal = java.util.GregorianCalendar;
      cal.setTime(javaDate);
      
      y = cal.get(java.util.Calendar.YEAR);
      mo = cal.get(java.util.Calendar.MONTH);
      d = cal.get(java.util.Calendar.DAY_OF_MONTH);
      h = cal.get(java.util.Calendar.HOUR_OF_DAY);
      mi = cal.get(java.util.Calendar.MINUTE);
      s = cal.get(java.util.Calendar.SECOND);
      ms = cal.get(java.util.Calendar.MILLISECOND);
      
      dn = datenum(y, mo + 1, d, h, mi, s + ms / 1000);

      % cross check...
      %[y , mo, d, h, mi, s]
      %[y , mo, d, h, mi, s] = datevec(dn)
    end
    function t = gps_to_unix(t_gps)
      % t = gps_to_unix(gpsTime)
      %   Converts GPS second to UNIX time
      %   (see also gps_time, unix_to_gps, unix_to_datenum)
      
      % this is the offset between Unix time (started Jan 1, 1970)
      % and GPS time (started Jan 6, 1980)
      gpsOffset = 315964800;
      
      % correct for leap seconds
      t = t_gps + gpsOffset - GWData.leap_seconds_in_gps(t_gps);
    end
    function t = unix_to_gps(t_unix)
      % t = unix_to_gps(gpsTime)
      %   Converts UNIX time to GPS second
      %   (see also gps_time, gps_to_unix, gps_to_datenum)
      
      % this is the offset between Unix time (started Jan 1, 1970)
      % and GPS time (started Jan 6, 1980)
      gpsOffset = 315964800;
      
      % convert to GPS time and add leap seconds
      t = t_unix - gpsOffset + GWData.leap_seconds_in_unix(t_unix);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Leap Seconds
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function leap_num = leap_seconds_in_unix(t_unix)
      % leap second correction
      %  datenum is tied to UNIX time, where leap seconds are removed
      %  so we have to put them back to convert from GPS to UNIX time
      
      % leap second UNIX times
      [~, leap_unix] = GWData.leap_seconds();
                              
      % count accumulated leap seconds
      leap_num = sum(leap_unix < t_unix);
    end
    function leap_num = leap_seconds_in_gps(t_gps)
      % leap second correction
      %  datenum is tied to UNIX time, where leap seconds are removed
      %  so we have to put them back to convert from GPS to Unix time
      
      % leap second GPS times
      [leap_gps, ~] = GWData.leap_seconds();
              
      % count accumulated leap seconds
      leap_num = sum(leap_gps < t_gps);
    end
    function [leap_gps, leap_unix, leap_datenum] = leap_seconds()
      % get timestamps for when leap seconds happened
      %  note that leap_gps and leap_unix are timezone independent
      %  while leap_datenum depends on timezone
      
      % NOTE: execution of this function takes tens of milliseconds!
      % tic; [leap_gps, leap_unix, leap_datenum] = GWData.leap_seconds(); toc
      % Elapsed time is 0.070834 seconds.

      % leap seconds since 1980 (updated January, 2015)
      leap_date = [...
        'Jul 01 1981 GMT'
        'Jul 01 1982 GMT'
        'Jul 01 1983 GMT'
        'Jul 01 1985 GMT'
        'Jan 01 1988 GMT'
        'Jan 01 1990 GMT'
        'Jan 01 1991 GMT'
        'Jul 01 1992 GMT'
        'Jul 01 1993 GMT'
        'Jul 01 1994 GMT'
        'Jan 01 1996 GMT'
        'Jul 01 1997 GMT'
        'Jan 01 1999 GMT'
        'Jan 01 2006 GMT'
        'Jan 01 2009 GMT'
        'Jul 01 2012 GMT'
        'Jul 01 2015 GMT'
        'Jul 01 2018 GMT'   % estimate
        'Jul 01 2021 GMT'   % estimate
        'Jul 01 2024 GMT'   % estimate
        'Jul 01 2027 GMT'   % estimate
        'Jul 01 2030 GMT'   % estimate
        'Jul 01 2033 GMT'   % estimate
        'Jul 01 2036 GMT'   % estimate
        'Jul 01 2039 GMT']; % estimate (~1ms / day => ~0.33s / year)
      
      % this is the offset between Unix time (started Jan 1, 1970)
      % and GPS time (started Jan 6, 1980)
      gpsOffset = 315964800;

      % convert to unix/gps/date numbers
      % datenum seems to have DST issues, so use Java functions instead
      % leap_datenum = datenum(leap_date, 'mmm dd yyyy zzz');
      leap_unix = zeros(size(leap_date, 1), 1);
      leap_gps = zeros(size(leap_date, 1), 1);
      leap_datenum = zeros(size(leap_date, 1), 1);
      dateFormatter = java.text.SimpleDateFormat('MMM dd yyyy z');
      for n = 1:size(leap_date, 1)
          % get UNIX time for each (comes in milliseconds)
          leap_unix(n) = dateFormatter.parse(leap_date(n, :)).getTime/1000;
          % remove gps offset, and add accumulated leap seconds
          %   (can't use unix_to_gps, since that comes here!)
          leap_gps(n) = (leap_unix(n) - gpsOffset) + n;
          leap_datenum(n) = GWData.unix_to_datenum(leap_unix(n));
      end      
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Time Zone Paring
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function date_num = tzconvert(date_str)
      % TZCONVERT  Convert date string to serial date number (time zone aware)
      % Matlab's builtin DATENUM function ignores time zone specifiers when
      % converting date strings (unless an explicit date string format is
      % provided).  For example:
      % >> datenum('01-jan-2015 00:00:00 CST')-datenum('01-jan-2015 00:00:00 PST')
      %
      % ans =
      %
      %      0
      %
      % TZCONVERT works around this shortcoming:
      % >> tzconvert('01-jan-2015 00:00:00 CST')-tzconvert('01-jan-2015 00:00:00 PST')
      %
      % ans =
      %
      %    -0.0833
      %
      % TZ formats accepted include: time offsets (+0100, -0800, etc),
      % US time zone abbreviations (EST, PDT, etc), and UTC or GMT.
      %
      % See also: DATENUM, DATESTR
      
      %%% Look for time zone specifiers in date_str
      tz_re = '(\<(+|-)[0-2][0-9][0-5][0-9]|UTC|GMT|(A|E|C|M|P|AK|HA)(S|D)T\>)';
      tz_idx = regexpi(date_str, tz_re, 'tokenExtents');
      
      if numel(tz_idx) > 1
        error(['multiple time zone specifiers found in date string: ' date_str]);
      end
      
      %%% Convert to datenum
      % no time zones => nothing to do
      if isempty(tz_idx)
        date_num = datenum(date_str);
        return;
      end
      
      % split the time zone from the rest of the string
      tz_idx = tz_idx{1};
      tz = date_str(tz_idx(1):tz_idx(2));
      date_str = [date_str(1:tz_idx(1)-1) date_str(tz_idx(2)+1:end)];
      
      % rewrite the date string in a known format
      date_str = [datestr(date_str, 'dd-mmm-yyyy HH:MM:SS') ' ' tz];
      
      % use java date libraries to make the conversion
      % datenum should be able to do this, but it's broken by DST
      % for example, the following is not zero (replace PDT with your local
      % time zone):
      % datenum('24-mar-2015 02:17:00')-datenum('24-mar-2015 02:17:00 PDT', 'dd-mmm-yyyy HH:MM:SS zzz')
      dateFormatter = java.text.SimpleDateFormat('dd-MMM-yyyy HH:mm:ss z');
      date_num = GWData.unix_to_datenum(dateFormatter.parse(date_str).getTime/1000);
      
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Kerberos Authentication
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function env_str = kerberos_env(kerb_path)
      % env_str = kerberos_env(kerb_path)
      %   set LANG and PATH environment variables needed to invoke Kerberos
      %   commands.

      % locale settings influence the printing of dates by klist
      env_str = 'LANG=posix LC_TIME=posix';
      if ispc
        env_str = 'set LANG=posix && set LC_TIME=posix &&';
      end

      % special path setting for Mac OS X (forces the use of MacPorts)
      if ismac && (nargin < 1 || isempty(kerb_path))
        kerb_path = '/opt/local/bin';
      end
      
      % special path setting for Windows (forces the use of MIT Kerberos)
      if ispc && (nargin < 1 || isempty(kerb_path))
        kerb_path = 'C:\Program Files\MIT\Kerberos\bin';
      end

      % apply path setting
      path_now = getenv('PATH');
      if ~strncmp(path_now, kerb_path, numel(kerb_path))
        if ~ispc
          env_str = [env_str ' PATH=' kerb_path ':' path_now];
        else
          env_str = [env_str ' path ' kerb_path ';' path_now ' &&'];
        end
      end
      
      % check for kerberos (system returns 0 when ok)
      if ~ispc
        [isNotOk, str] = system([env_str ' which kinit']);
      else
        [isNotOk, str] = system([env_str ' where kinit']);
      end
      if isNotOk
        error('kinit not found.  Unable to setup Kerberos ticket.')
      elseif ~strncmp(str, kerb_path, numel(kerb_path))
        warning('using kinit at %s, expect it at %s', str, kerb_path)
      end
    end
    function [is_ready, end_time] = make_kerberos_ready(srv, kerb_path)
      % [is_ready, end_time] = make_kerberos_ready(srv, kerb_path)
      %   look for a valid kerberos ticket for a particular service principal
      %   and use kinit to make a new ticket if none is found.
      %
      % srv = Kerberos service principal (default = 'LIGO.ORG')
      % kerb_path = path for kinit and klist (default = '/opt/local/bin' for Macs)
      %
      % is_ready = true if a ticket is found or created, false otherwise
      % end_time = matlab date number for end of ticket validity (see datenum)
      
      % default service principal
      if nargin < 1
        srv = 'LIGO.ORG';
      end
      
      if nargin < 2
        kerb_path = '';
      end
      
      env_str = GWData.kerberos_env(kerb_path);

      % initialize kerberos
      [is_ready, end_time] = GWData.is_kerberos_ready(srv);
      if is_ready
        % we already have a ticket
        return
      else
        % we need to get a ticket
        fprintf('== GW Data: Kerberos authentication ==\n')
        if ~ispc
          username = input([srv ' user name: '], 's');
          if system([env_str ' kinit ' username '@' srv]);
            error('kinit failed.  Bad password?')
          end
        else
          if system([env_str ' "MIT Kerberos.exe" -kinit']);
            error('kinit failed.  Bad password?')
          end
        end
        
        % now get ticket info
        [is_ready, end_time] = GWData.is_kerberos_ready(srv);
      end
    end
    function [is_ready, end_time] = is_kerberos_ready(srv, kerb_path)
      % [is_ready, end_time] = is_kerberos_ready(srv, kerb_path)
      % look for a valid kerberos key for a particular service principal
      %   this assumes that the path is set properly (see
      %   make_kerberos_ready)
      %
      % %%% no cache?
      % klist: No credentials cache found (ticket cache FILE:/tmp/krb5cc_501)
      %
      % %%% found cache...
      % Ticket cache: FILE:/tmp/krb5cc_501
      % Default principal: matthew.evans@LIGO.ORG
      %
      % Valid starting       Expires              Service principal
      % 12/09/2014 15:24:34  12/10/2014 15:24:34  krbtgt/LIGO.ORG@LIGO.ORG
      
      
      if nargin < 2
        kerb_path = '';
      end
      
      env_str = GWData.kerberos_env(kerb_path);

      % first line of ticket info
      first_line = 4;
      
      % return values, unless we find otherwise
      is_ready = false;
      end_time = 0;
      
      % call klist to get list of tickets
      [exit_status, result] = system([env_str ' klist']);
      
      % klist failed, so we're definitely not ready
      if exit_status ~= 0
        return
      end
      
      % split result into lines
      %result_lines = strsplit(result, {'\n', '\r'});
      result_lines = GWData.splitlines(result);
      
      if ~iscell(result_lines) || numel(result_lines) < first_line
        % not enough lines
        return
      end
      
      
      % look for service principal in tickets
      hasSP = strfind(result_lines, srv);
      
      for n = first_line:numel(hasSP)
        % if this ticket mentions the SP, look at the date strings
        if ~isempty(hasSP{n})
          % looking for lines like:
          % 12/09/2014 15:24:34  12/10/2014 15:24:34  krbtgt/LIGO.ORG@LIGO.ORG
          date_time_strs = GWData.splitwords(result_lines{n});
          if numel(date_time_strs) > 4
            % get data number for end time, and compare to time now
            end_time = datenum([date_time_strs{3} ' ' date_time_strs{4}]);
            if end_time > now
              % this ticket is ok!
              is_ready = true;
              return
            end
          end
        end
      end
      
      % didn't find a valid ticket
      is_ready = false;
    end

    % same as strsplit(result, {'\n', '\r'});
    % for old matlab versions
    function strlist = splitlines(str)
      nn = strfind(str, char(10)); % \n
      nr = strfind(str, char(13)); % \r
      nnr = strfind(str, [char(10) char(13)]);
      nrn = strfind(str, [char(13) char(10)]);
      
      nAll = unique([nn, nr, nnr, nrn]);
      if isempty(nAll)
        strlist = str;
      else
        nLast = 0;
        strlist = {};
        for n = 1:numel(nAll)
          nNext = nAll(n);
          if nNext > nLast + 1
            strlist(end + 1) = {str((nLast + 1):(nNext - 1))}; %#ok<AGROW>
          end
          nLast = nNext;
        end
      end
    end
    
    % same as strsplit(result, {' ', '\t'});
    % for old matlab versions
    function strlist = splitwords(str)
      nt = strfind(str, char(9));  % \t
      ns = strfind(str, ' ');
      
      nAll = unique([nt, ns]);
      if isempty(nAll)
        strlist = str;
      else
        nLast = 0;
        strlist = {};
        for n = 1:numel(nAll)
          nNext = nAll(n);
          if nNext > nLast + 1
            strlist(end + 1) = {str((nLast + 1):(nNext - 1))}; %#ok<AGROW>
          end
          nLast = nNext;
        end
        if nLast < numel(str)
          strlist(end + 1) = {str((nLast + 1):end)};
        end
      end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Data Processing
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function y = resample(x, p, q)
      % y = my_resample(x, p, q)
      %   use fitting to resample without end glitches
      
      % if x is too short, just demean and return y
      if numel(x) < 10
        xm = mean(x);
        y = resample(x - xm, p, q) + xm;
        return
      end
      
      % fit a polynomial to the end points
      toff = numel(x) / 2;
      tx = (0:(numel(x) - 1))' - toff;
      xm = abs(mean(x(1:3) - x(end-2:end)));  % shift from start to end
      xs = std(x(1:3)) + std(x(end-2:end));   % spread of data
      if numel(x) < 30 || xm < 5 * xs
        % not may points, or pretty flat data, so use a linear fit
        pf = polyfit(tx([1:3, (end-2:end)]), x([1:3, (end-2:end)]), 1);
      else
        % more points, so use a cubic fit
        pf = polyfit(tx([1:10, (end-9:end)]), x([1:10, (end-9:end)]), 3);
      end
      % make a new x that is zero at both ends
      xz = x - polyval(pf, tx);
      
      % resample
      yz = resample(xz, p, q);
      
      % add back in polynomial fit
      ty = (0:(numel(yz) - 1))' * q / p - toff;
      y = yz + polyval(pf, ty);
      
      %plot(tx, [x, xz], ty, [y, yz, polyval(pf, ty)])
      %pause
    end
  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Global Variable Save/Restore
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % These functions need to import global variables into their own
    % workspace.  So they stash their own local variables in Matlab's
    % appdata, to avoid colliding with the global variable names.

    function globals = save_globals()
      globals = struct();
      vars = who('global');
      for n = 1:numel(vars)
        locals = struct();
        locals.n = n;
        locals.vars = vars;
        locals.globals = globals;
        setappdata(0, 'GWData_sg_locals', locals);
        setappdata(0, 'GWData_sg_var', vars{n});
        eval(['global ' vars{n}]);
        setappdata(0, 'GWData_sg_val', eval(getappdata(0, 'GWData_sg_var')));
        locals = getappdata(0, 'GWData_sg_locals');
        n = locals.n; %#ok<FXSET>
        vars = locals.vars;
        globals = locals.globals;
        globals.(vars{n}) = getappdata(0, 'GWData_sg_val');
      end
      if isappdata(0, 'GWData_sg_locals')
        rmappdata(0, 'GWData_sg_locals');
        rmappdata(0, 'GWData_sg_var');
        rmappdata(0, 'GWData_sg_val');
      end
    end
    
    function restore_globals(globals)
      vars = fieldnames(globals);
      for n = 1:numel(vars)
        locals = struct();
        locals.n = n;
        locals.vars = vars;
        locals.globals = globals;
        setappdata(0, 'GWData_rg_locals', locals);
        setappdata(0, 'GWData_rg_var', vars{n});
        setappdata(0, 'GWData_rg_val', globals.(vars{n}));
        eval(['global ' vars{n}]);
        eval([getappdata(0, 'GWData_rg_var') '= getappdata(0, ''GWData_rg_val'');']);
        locals = getappdata(0, 'GWData_rg_locals');
        n = locals.n; %#ok<FXSET>
        vars = locals.vars;
        globals = locals.globals;
      end
      if isappdata(0, 'GWData_rg_locals')
        rmappdata(0, 'GWData_rg_locals');
        rmappdata(0, 'GWData_rg_var');
        rmappdata(0, 'GWData_rg_val');
      end
    end
  end

  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Public Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods
    function obj = GWData()
      % setup kerberos path
      if ismac
        obj.kerb_path = '/opt/local/bin';
      end
      
      % setup site info
      obj.site_info(1:3) = obj.site_info;
    
      obj.site_info(1).name = 'L1';
      obj.site_info(1).server = 'nds.ligo-la.caltech.edu';
      
      obj.site_info(2).name = 'H1';
      obj.site_info(2).server = 'nds2.ligo-wa.caltech.edu';
      
      obj.site_info(3).name = 'C1';
      obj.site_info(3).server = 'nds40.ligo.caltech.edu';
      
      % configure backup servers
      obj.server_info(1:4) = obj.server_info;
      obj.server_info(1).server = 'nds.ligo.caltech.edu';
      obj.server_info(2).server = 'ldas-pcdev1.ligo-la.caltech.edu';
      obj.server_info(3).server = 'ldas-pcdev1.ligo-wa.caltech.edu';
      obj.server_info(4).server = 'nds2.ligo.caltech.edu';
      
      % save list of site names
      obj.site_list = {obj.site_info.name};
      
      % check for local environment
      ndsserver = getenv('NDSSERVER');
      if ~isempty(ndsserver)
        ndsserver = regexp(ndsserver, ',', 'split');
        ndsserver = regexp(ndsserver{1}, ':', 'split');
        server = ndsserver{1};
        port = 31200;
        if numel(ndsserver) > 1
            port = str2double(ndsserver{2});
        end
        % need to know which site the server is associated with
        ifo = getenv('IFO');
        if ~isempty(ifo)
          site_idx = strcmp(ifo, obj.site_list);
          if any(site_idx)
            % replace existing site_info entry
            obj.site_info(site_idx).server = server;
            obj.site_info(site_idx).port = port;
          else
            % add new site_info entry and update site_list
            obj.site_info(end+1).name = ifo;
            obj.site_info(end).server = server;
            obj.site_info(end).port = port;
            obj.site_list = {obj.site_info.name};
          end
          disp(['Using NDS server ' ndsserver{1} ' for ' ifo]); 
        else
          warning('Ignoring local $NDSSERVER setting for unknown site');
        end
      end
    end
    function [data, t, info] = ...
        fetch(obj, start_time, end_time, channel_list, data_rate)
      
      % [data, t, info] = gwd.fetch(start_time, end_time, channel_list, data_rate)
      %
      % Fetch data from NDS2 servers.
      %
      % == Arguments ==
      % start_time = data starts at this GPS second
      %            If start_time corresponds to a date before January 1, 2000
      %            (e.g., start_time < 630748814), it is taken as the number
      %            of seconds BEFORE the current time.  To get data from 1 hour
      %            ago, for instance, use start_time = 3600.
      %              If start_time is a string, vector, or cell array, it is
      %            passed to GWData.gps_time for conversion.  Note, this
      %            uses local time, not UTC (see gps_time and tzconvert).
      %
      % end_time = data ends at this GPS second
      %            If end_time corresponds to a date before January 1, 2000,
      %            it is taken as the duration of the data segment.
      %              If end_time is a string, vector, or cell array, it is
      %            passed to GWData.gps_time for conversion.
      %
      % channel_list = channel name, or cell array of channel names to fetch
      %            In many cases, adding ".mean,s-trend" (or ".mean,m-trend")
      %            to the end of a channel name is sufficient to get the
      %            second trend (or minute trend) mean value.
      %
      % data_rate = rate to resample the data to before returning
      %            If not specified, or given as [], the rate of the first
      %            channel in the channel list will be used.  If given as
      %            'mDV', data will be returned in a structure array with
      %            one entry for each channel.
      %
      % == Return Values ==
      % data = Nsample x Nchannel array of data
      %        (i.e., data(:, 2) is the data for the second channel)
      % or in 'mDV' format, data = 1xNchannel struct array with fields:
      %   name = channel name
      %   data = full data points
      %   rate = sample rate
      %   start = actual start GPS
      %   duration = actual data duration
      % t = time vector relative to start_time
      % info = structure with the following fields
      %   start_time = actual start GPS
      %   end_time = actual end GPS
      %   duration = actual data duration
      %   data_buffers = full data returned from NDS fetch function
      %   conn = NDS connection used to fetch this data
      %          The connection will be closed, unless fetch is invoked
      %          with a duration of 0. This may be useful for later calls
      %          to findChannels, etc.
      %
      % ====== Examples ======
      %
      % % start with a GW Data object
      % gwd = GWData;
      %
      % % get the minute trend of IMC input power from a few hours ago
      % [data, t] = gwd.fetch(5 * 3600, 1000, 'L1:IMC-PWR_IN_OUT16.mean,m-trend');
      % plot(t, data)
      %
      % % get 16Hz data for Y-arm power and input power
      % % start time is 2 hours ago, duration is 1000s
      % [data, t] = gwd.fetch(2 * 3600, 1000, ...
      %   {'L1:ASC-Y_TR_B_SUM_OUT16', 'L1:IMC-PWR_IN_OUT16'});
      % plot(t, [data(:, 1) / 1e3, data(:, 2)])
      %
      % % -- find a channel, then get data --
      % % initialize Kerberos (if not already done)
      % gwd.make_kerberos_ready;
      %
      % % connect to server and find some channels
      % conn = nds2.connection('nds.ligo-la.caltech.edu', 31200);
      % fc = conn.findChannels('L1:LSC-X_TR*OUT*.mean*')
      %
      % % look through the channels to find the one you want... say #3
      % % <L1:LSC-X_TR_A_LF_OUTPUT.mean,m-trend (0.0166667Hz, MTREND, FLOAT64)>
      % % and then get some data for it
      % [data, t, info] = gwd.fetch(5 * 3600, 1000, fc(3).getName);
      % t0 = info.start_time;  % start time GPS
      %
      % % change server for H1 (note: H1 is second in GWData.site_list)
      % gwd.site_info(2).server = 'nds.ligo.caltech.edu';
      %
      % ====== Troubleshooting ======
      %  Start by looking under "Matlab Tools" on the remote data access wiki:
      %  https://wiki.ligo.org/viewauth/RemoteAccess
      %
      % --> NDS2 not found <--
      %  If you installed NDS2, but matlab can't find it try
      %  >> edit classpath.txt
      %
      %  and add this to the end of the file:
      %  # NDS2
      %  /opt/local/lib/java
      %  (or replace /opt/local/lib/java with your java class path)
      %
      % --> kinit not found <--
      %  kinit is used to obtain and cache Kerberos ticket-granting ticket.
      %  NDS2 needs this for authentication.  Try 'which kinit' on the
      %  command line and Google from there.
      %
      % --> kinit failed <--
      %  wrong user name or password?  This should be your "albert.einstein"
      %  username and corresponding ligo.org password.
      %

      % TODO:
      % catch NDS errors and try backup servers
      %   use CIS to diagnose "No data found" problems

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % setup dependencies
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % check for NDS2
      if ~exist('nds2.connection', 'class')
        % check hardcoded MacPorts path /opt/local/bin, which may not otherwise
        % be picked up by the matlab app's PATH environment variable
        pathsToCheck = {'', '/opt/local/bin/'};
        for n = 1:numel(pathsToCheck)
          [status, output] = system([pathsToCheck{n} 'nds-client-config --javaclasspath']);
          if ~status
            path = deblank(output);
            disp(['Found nds2-client library in ' path]);
            % javaaddpath is evil: it clears global variables and many
            % other aspects of the environment. So try to save and restore
            % the globals, and ask the user to install nds2-client in the
            % static java path.
            warning(['nds2-client library was found in ' path ', which is not in Matlab''s java path.' char(10) ...
                'Please see "help GWData" for instructions to complete the installation.']);
            globals = GWData.save_globals();
            javaaddpath(path);
            GWData.restore_globals(globals);
            break;
          end
        end
        if ~exist('nds2.connection', 'class')
          error('Can''t find nds2-client (use "help GWData.fetch" for more info)');
        end
      end

      % if this was just for initialization...
      if nargin == 1
        % initialize kerberos
        [obj.kerb_is_ready, obj.kerb_end_time] = ...
          GWData.make_kerberos_ready(obj.kerb_srv, obj.kerb_path);
        % and return empty
        return
      end
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % interpret arguments
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      % record present time for later use
      gps_time_now = floor(GWData.gps_time);
      
      % validate arguments
      if ~isa(start_time, 'numeric') || ~isscalar(start_time)
        if ~ischar(start_time)
          error('start_time must be a GPS time or date string');
        elseif any(strncmp(start_time, obj.site_list, 2))
          error('start_time looks like a channel name');
        end
      end
      if ~isa(end_time, 'numeric') || ~isscalar(end_time)
        if ~ischar(end_time)
          error('end_time must be a GPS time or date string');
        elseif any(strncmp(end_time, obj.site_list, 2))
          error('end_time looks like a channel name');
        end
      end
      if ischar(channel_list)
        channel_list = {channel_list};
      end
      if ~iscellstr(channel_list)
        error('channel list must be a cell array of channel names');
      end

      % start and end times to gps values
      start_time = GWData.gps_convert(start_time, gps_time_now, false);
      end_time = GWData.gps_convert(end_time, start_time, true);
      
      % make start and end times into integers
      % (and ensure that floating point errors don't cause problems)
      start_time = floor(start_time + 1e-6);
      end_time = ceil(end_time - 1e-6);
      
      % check data rate (default to first channel rate if not given)
      if nargin < 5
        data_rate = [];
      end
      
      % set some background info
      num_channel = numel(channel_list);
      duration = end_time - start_time;
      
      % check validity of end_time
      if duration < 0
        error('end_time is before start_time (%d < %d)', end_time, start_time)
      end
      
      latency_time = gps_time_now - end_time;
      if latency_time < 0
        error('end_time is in the future (%d > %d)', end_time, gps_time_now)
      end
      if latency_time < 30
        error('end_time is too close to the present.  Try again in 30s.')
      end
      
      % if no channels to read, return empty
      if num_channel == 0
        data = [];
        t = [];
        info.start_time = start_time;
        info.end_time = end_time;
        info.duration = duration;
        return
      end
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % look for minute trends, and adjust times
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      nMinTrend = strfind(channel_list, 'm-trend');
      hasMinTrend = ~isempty([nMinTrend{:}]);
      
      % if there are minute trends in the list, adjust to even minutes
      if hasMinTrend
        if rem(start_time, 60) ~= 0
          start_time  = start_time - rem(start_time, 60);
          warning('start_time adjusted to even minute for m-trend, now %d', start_time);
        end
        if rem(end_time, 60) ~= 0
          end_time  = end_time + 60 - rem(end_time, 60);
          warning('end_time adjusted to even minute for m-trend, now %d', end_time);
        end
        
        % update the duration
        duration = end_time - start_time;
      end
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % connect to network data server
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      % determine site
      site_name = channel_list{1}(1:2);
      site_num = find(strncmp(obj.site_list, site_name, 1), 1);
      if isempty(site_num)
        error('Unknown site name %s in channel %s.', site_name, channel_list{1});
      end
      server = obj.site_info(site_num).server;
      port = obj.site_info(site_num).port;
      
      % check others
      for n = 2:num_channel
        if ~strcmp(site_name, channel_list{2}(1:2))
          error('All channels must be from the same site.');
        end
      end
      
      % initialize kerberos, unless connecting to the NDS1 port 8088
      if port ~= 8088
        [obj.kerb_is_ready, obj.kerb_end_time] = ...
          GWData.make_kerberos_ready(obj.kerb_srv, obj.kerb_path);
      end

      % connect to server
      disp(['Connecting to NDS server ' server]);
      conn = nds2.connection(server, port);

      % if no data to read, return empty
      if duration == 0
        data = [];
        t = [];
        info.start_time = start_time;
        info.end_time = end_time;
        info.duration = duration;
        info.conn = conn;
        return
      end

      s = '';
      if numel(channel_list) > 1
        s = 's';
      end
      disp(['Fetching ' num2str(numel(channel_list)) ' channel' s ...
        ', start GPS ' num2str(start_time), ', duration ' num2str(duration) ' sec']);

      cleanup_conn = onCleanup(@() conn.close());      

      % Provide a status bar when many channels are requested
      h_win = 0;
      if numel(channel_list) > obj.nds_max_chans
        h_win = waitbar(0, ['Fetching ' num2str(numel(channel_list)) ' channels...'], ...
          'CreateCancelBtn', 'setappdata(gcbf, ''canceling'', 1)', 'Name', 'GWData');
        setappdata(h_win, 'myX', 0);
        setappdata(h_win, 'canceling', 0);
        cleanup_window = onCleanup(@() delete(h_win));
      end
      % Define a callback to update the status bar
      function cb(inc)
        if h_win ~= 0
          if getappdata(h_win, 'canceling')
            error('GWData:userCancelled', 'NDS data request cancelled')
          end
          x = getappdata(h_win, 'myX') + inc/numel(channel_list);
          setappdata(h_win, 'myX', x);
          waitbar(x, h_win);
        end
      end

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % get data for each channel
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      data_buffers = obj.rfetch(conn, channel_list, start_time, end_time, @cb);

      clear cleanup_conn;
      if h_win ~= 0
          clear cleanup_window;
          drawnow;
      end

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % resample and repackage data
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      % validate
      if isempty(data_buffers)
        error('Unable to fetch data from %s.', server);
      end
      
      % determine rate, if not already known
      if isempty(data_rate)
        data_rate = data_buffers(1).getLength / duration;
      end

      % output format selection
      if strcmp(data_rate, 'mDV')
        t = [];
        data = struct('name', {}, 'data', {}, 'rate', {}, 'start', {}, 'duration', {});
        for n = 1:numel(data_buffers)
          data(n) = struct('name', data_buffers(n).getChannel.getName, ...
            'data', data_buffers(n).getData, ...
            'rate', data_buffers(n).getChannel.getSampleRate, ...
            'start', data_buffers(n).getGpsSeconds + data_buffers(n).getGpsNanoseconds/10^9, ...
            'duration', data_buffers(n).getLength/data_buffers(n).getChannel.getSampleRate);
        end
      else      
        % initialize time vector and data space
        num_sample = duration * data_rate;
        t = (0:(num_sample - 1))' / data_rate;
        data = zeros(num_sample, num_channel);

        % loop over channels to resample, if needed
        for n = 1:num_channel
          this_data = double(data_buffers(n).getData);
          if data_buffers(n).getLength == num_sample
            % no need to resample
            data(:, n) = this_data;
          else
            % resample the data
            data(:, n) = GWData.resample(this_data, ...
              num_sample, data_buffers(n).getLength);
          end
        end
      end
      
      % for the record
      info.start_time = start_time;
      info.end_time = end_time;
      info.duration = duration;
      info.conn = conn;
      info.data_buffers = data_buffers;
      
      obj.last_start_time = start_time;
      obj.last_end_time = end_time;
      obj.last_channel_list = channel_list;
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Protected Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods (Access = protected)
    function bufs = rfetch(obj, conn, chan_list, start_time, end_time, cb)
      % recursive fetch helper function
      bufs = {};
      if numel(chan_list) < 1
        return;
      end
      if numel(chan_list) > obj.nds_max_chans
        for n = 1:obj.nds_max_chans:numel(chan_list)
          endN = min(numel(chan_list), n+obj.nds_max_chans-1);
          bufsN = obj.rfetch(conn, chan_list(n:endN), start_time, end_time, cb);
          bufs = [bufs bufsN]; %#ok<AGROW>
        end
        return;
      end
      try
        bufs = conn.fetch(start_time, end_time, chan_list);
        cb(numel(chan_list));
        return;
      catch exc
        if strcmp(exc.identifier, 'GWData:userCancelled')
          rethrow(exc);
        end
        if numel(chan_list) == 1
          disp(['Failed to fetch channel ' chan_list{1}]);
          cb(numel(chan_list));
          rethrow(exc);
        end
        chan_list1 = chan_list(1:floor(end/2));
        chan_list2 = chan_list(floor(end/2)+1:end);
        bufs = [obj.rfetch(conn, chan_list1, start_time, end_time, cb)...
          obj.rfetch(conn, chan_list2, start_time, end_time, cb)];
      end
    end
  end
end
