({
    getAllActivitys: function (component) {
        // retrieve server method
        var action = component.get("c.getActivityTimeline");

        // set method paramaters
        action.setParams({
            "recordId": component.get("v.recordId"),
            "includeChildren": component.get("v.includeChildren")
        });

        // set call back instructions
        action.setCallback(this, function (response) {
            if (response.getState() === "SUCCESS") {
                var timelineGroups = response.getReturnValue();
                var activeSections = [];
                timelineGroups.forEach(function (timelineGroup, index) {
                    var sectionName = 'Section' + index;
                    activeSections.push(sectionName);
                    timelineGroup.sectionName = sectionName;
                    timelineGroup.items.forEach(function (item) {
                        item.isExpanded = false;
                    });
                });

                let loadLimiter = {
                    limit: 2,
                    load: 2 < timelineGroups.length
                };

                component.set("v.loadLimiter", loadLimiter);
                console.log(timelineGroups)
                // assign server retrieved items to component variable
                component.set("v.timelineGroups", timelineGroups);
                component.set("v.activeSections", activeSections);
                component.set("v.isLoading", false);
                component.set("v.loadTimeline", true);
            }
        });

        // queue action on the server
        $A.enqueueAction(action);
    }
})