({
	// common reusable function for toggle sections
	toggleActivityDetail : function(component, event, helper) {
        component.set("v.isExpanded", !component.get("v.isExpanded"));
	}
})