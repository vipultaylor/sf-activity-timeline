({
	// common reusable function for toggle sections
	toggleActivityDetail: function (component, event, helper) {
		component.set("v.isExpanded", !component.get("v.isExpanded"));
	},
	handleMenuClick: function (component, event, helper) {
		const actionItem = event.getParam("value");
		if (actionItem === 'Edit') {
			component.set('v.isEdit', true);
		}

	},
	closeModel: function (component, event, helper) {
		component.set('v.isEdit', false);
	},
	save: function (component, event, helper) {
		component.find("editForm").get("e.recordSave").fire();
	},
})