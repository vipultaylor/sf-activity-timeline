global  class ActivityTimelineGroup {
    @AuraEnabled
    public String name {get;set;}

    @AuraEnabled
    public List<ActivityTimelineModel> items {get;set;}

    public ActivityTimelineGroup(String name, List<ActivityTimelineModel> items){
        this.name = name;
        this.items = items;
    }

    public ActivityTimelineGroup(Long dateAsLong, List<ActivityTimelineModel> items){
        this.name = Utils.getMonthName(DateTime.valueOf(dateAsLong).month()) + ' • ' + DateTime.valueOf(dateAsLong).year();
        this.items = items;
    }
}