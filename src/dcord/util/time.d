/// Utilties related to epoch time
module dcord.util.time;

version (Posix) {
  import core.sys.posix.sys.time;

  /// Returns UTC time in microseconds
  long getEpochTimeMicro() {
    timeval t;
    gettimeofday(&t, null);
    return 10_000_00 * t.tv_sec + t.tv_usec;
  }

  /// Returns UTC time in milliseconds.
  long getEpochTimeMilli() {
    timeval t;
    gettimeofday(&t, null);
    return t.tv_sec * 1000 + t.tv_usec / 1000;
  }

  /// Returns UTC time in seconds.
  long getEpochTime() {
    return getEpochTimeMilli() / 1000;
  }
}

version (Windows) {
  import core.sys.windows.winbase;

  /// Returns UTC time in milliseconds.
  long getEpochTimeMilli() {
    SYSTEMTIME systemTime;
    GetSystemTime(&systemTime);
    FILETIME fileTime;
    SystemTimeToFileTime( &systemTime, &fileTime );
    long fileTimeNano100;
    fileTimeNano100 = ((cast(long)fileTime.dwHighDateTime) << 32) + fileTime.dwLowDateTime;
    long posixTime = fileTimeNano100/10_000 - 116_444_736_000_00;
    return posixTime;
  }

  /// Returns UTC time in seconds.
  long getEpochTime() {
    return getEpochTimeMilli() / 1000;
  }
}
