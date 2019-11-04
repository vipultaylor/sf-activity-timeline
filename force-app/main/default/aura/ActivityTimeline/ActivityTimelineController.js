({
	doInit : function(component, event, helper) {
       	// retrieve server method
        var action = component.get("c.getActivityTimeline");
        
        // set method paramaters
        action.setParams({
            "recordId" : component.get("v.recordId"),
            "includeChildren": component.get("v.includeChildren")
        });

        // set call back instructions
        action.setCallback(this, function(response){
            if (response.getState() === "SUCCESS") {
                var timelineGroups = response.getReturnValue();
                var activeSections = [];
                timelineGroups.forEach(function(timelineGroup, index){
                    var sectionName = 'Section'+index;
                    activeSections.push(sectionName);
                    timelineGroup.sectionName = sectionName;
                });

                // assign server retrieved items to component variable
                console.log(timelineGroups);
                component.set("v.timelineGroups", timelineGroups);
                component.set("v.activeSections", activeSections);
            }
        });
        
        // queue action on the server
        $A.enqueueAction(action);
    },
    
    showSpinner : function(component, event, helper) {
        component.set("v.isLoading", true); 
    },
    
    hideSpinner : function(component, event, helper) {
        component.set("v.isLoading", false); 
    },
})