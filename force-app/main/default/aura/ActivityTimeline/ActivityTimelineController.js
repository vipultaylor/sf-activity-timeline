({
    doInit: function (component, event, helper) {
        //Check for component context
        const isMobile = $A.get("$Browser.formFactor") === 'PHONE';
        component.set('v.isMobile', isMobile);
        helper.getAllActivitys(component);
    },
    refreshActivitys: function (component, event, helper) {
        component.set("v.isLoading", true)
        helper.getAllActivitys(component);
    },
    toggleExpand: function (component, event, helper) {
        let isExpandAll = !component.get("v.isExpandAll");
        let timelineGroups = component.get("v.timelineGroups");
        //Expanding All Activitys
        timelineGroups.forEach(function (section) {
            section.items.forEach(function (item) {
                item.isExpanded = isExpandAll;
            });
        })
        component.set("v.timelineGroups", timelineGroups)
        component.set('v.isExpandAll', isExpandAll);
    },
    loadActivitys: function (component, event, helper) {
        let timelineGroups = component.get("v.timelineGroups");
        let loadLimiter = component.get("v.loadLimiter")

        loadLimiter.limit += 1;
        loadLimiter.load = loadLimiter.limit < timelineGroups.length;

        component.set("v.loadLimiter", loadLimiter);
    },
    showSpinner: function (component, event, helper) {
        component.set("v.isLoading", true);
    },

    hideSpinner: function (component, event, helper) {
        component.set("v.isLoading", false);
    },
})