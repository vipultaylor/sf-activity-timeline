public class Utils {
    private static Map<Integer, String> MONTH_NAMES = new Map<Integer, String>{
        1 => System.Label.Month_January,
        2 => System.Label.Month_February,
        3 => System.Label.Month_March,
        4 => System.Label.Month_April,
        5 => System.Label.Month_May,
        6 => System.Label.Month_June,
        7 => System.Label.Month_July,
        8 => System.Label.Month_August,
        9 => System.Label.Month_September,
        10 => System.Label.Month_October,
        11 => System.Label.Month_November,
        12 => System.Label.Month_December
    };

    //--------------------------------------------------------------------
    // Date Utils
    //--------------------------------------------------------------------
    public static String getMonthName(Integer month){
        return MONTH_NAMES.get(month);
    }
}