public with sharing class DateTimeUtility {
    /**
     * @description Converts a Date to a DateTime with a specified hour
     * @param dt The Date to convert
     * @param hr The hour (0-23) to set for the DateTime
     * @return DateTime instance set at the specified hour on the given date
     */
    public static Datetime toDateAddHours(Date dt, Decimal hr) {
        if (dt == null || hr == null) return null;
        // Time.newInstance accepts Integer, so casting Decimal to Integer is recommended
        return DateTime.newInstance(dt, Time.newInstance(hr.intValue(), 0, 0, 0));
    }
    /**
     * @description Converts a DateTime to a Date based on the user's local timezone
     * @param dtValue The DateTime to convert
     * @return Date in the user's local timezone
     */
    public static Date toDateInUserTimezone(DateTime dtValue) {
        if (dtValue == null) return null;
        TimeZone tz = UserInfo.getTimeZone();
        String dateStr = dtValue.format('yyyy-MM-dd', tz.getId());
        return Date.valueOf(dateStr);
    }
    
    /**
     * @description Calculates the GMT DateTime for the start of the day (00:00:00) in the user's timezone
     * @param dateValue The Date to convert
     * @return DateTime representing the start of the day in GMT
     */
    public static DateTime getStartOfDayInGmt(Date dateValue) {
        if (dateValue == null) return null;
        TimeZone tz = UserInfo.getTimeZone();
        DateTime dtGmt = DateTime.newInstanceGmt(dateValue, Time.newInstance(0, 0, 0, 0));
        Integer offsetMs = tz.getOffset(dtGmt);
        return dtGmt.addSeconds(-offsetMs / 1000);
    }
    
    /**
     * @description Calculates the GMT DateTime for the end of the day (23:59:59) in the user's timezone
     * @param dateValue The Date to convert
     * @return DateTime representing the end of the day in GMT
     */
    public static DateTime getEndOfDayInGmt(Date dateValue) {
        if (dateValue == null) return null;
        TimeZone tz = UserInfo.getTimeZone();
        DateTime dtGmt = DateTime.newInstanceGmt(dateValue, Time.newInstance(23, 59, 59, 0));
        Integer offsetMs = tz.getOffset(dtGmt);
        return dtGmt.addSeconds(-offsetMs / 1000);
    }
    
    /**
     * @description Converts a GMT DateTime to a formatted string in the user's timezone
     * @param datetimeValue The GMT DateTime to convert
     * @return String formatted as 'yyyy-MM-dd HH:mm:ss' in the user's timezone
     */
    public static String toDateTimeInUserTimezoneFormatted(DateTime datetimeValue) {
        return toDateTimeInUserTimezoneFormatted(datetimeValue, null);
    }
    
    /**
     * @description Converts a GMT DateTime to a formatted string based on a specific user's timezone
     * @param datetimeValue The GMT DateTime to convert
     * @param userId The ID of the user whose timezone will be used (defaults to current user if null)
     * @return String formatted as 'yyyy-MM-dd HH:mm:ss' in the specified user's timezone
     */
    public static String toDateTimeInUserTimezoneFormatted(DateTime datetimeValue, String userId) {
        if (datetimeValue == null) return null;
        
        TimeZone tz;
        if (userId == null) {
            tz = UserInfo.getTimeZone();
        } else {
            List<User> users = [SELECT TimeZoneSidKey FROM User WHERE Id = :userId LIMIT 1];
            if (!users.isEmpty()) {
                tz = TimeZone.getTimeZone(users[0].TimeZoneSidKey);
            } else {
                tz = UserInfo.getTimeZone();
            }
        }
        
        return datetimeValue.format('yyyy-MM-dd HH:mm:ss', tz.getId());
    }
}