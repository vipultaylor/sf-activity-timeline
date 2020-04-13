public class ActivityTimelineController {
    @AuraEnabled
    public static List<ActivityTimelineGroup> getActivityTimeline(Id recordId, Boolean includeChildren) {
        //Find out the Sobject type of the recordId passed
        Schema.SObjectType sobjType = recordId.getSobjectType();

        Set<Id> whatIdSet = new Set<Id>();
        Set<Id> whoIdSet = new Set<Id>();
        Set<Id> taskIdSet = new Set<Id>();
        Set<Id> eventIdSet = new Set<Id>();

        //Add the record passed
        if(sobjType == Schema.Contact.SObjectType) {
			whoIdSet.add(recordId);
        } else {
        	whatIdSet.add(recordId);
        }
        
        //Process Accounts
        if(sobjType == Schema.Account.SObjectType){
            //Process Other 'Child' Objects
            if(includeChildren) {
                //Contacts
                Map<Id, Contact> mapDirectContacts = new Map<Id, Contact>([SELECT Id FROM Contact WHERE AccountId =: recordId]);
                whoIdSet.addAll(mapDirectContacts.keySet());
                
                /* Uncomment if multi activity sharing is
                List<TaskRelation> tr=[SELECT Id, RelationId, TaskId FROM TaskRelation WHERE RelationId IN:mapDirectContacts.keySet()];
                for(TaskRelation t:tr) taskIdSet.add(t.TaskId);
                List<EventRelation> er=[SELECT Id, RelationId, EventId FROM EventRelation WHERE RelationId IN:mapDirectContacts.keySet()];
                for(EventRelation e:er) eventIdSet.add(e.EventId);
                */
                //Opportunities
                Map<Id, Opportunity> mapDirectOpportunities = new Map<Id, Opportunity>([SELECT Id FROM Opportunity WHERE AccountId =: recordId]);
                whatIdSet.addAll(mapDirectOpportunities.keySet());

                //Cases
                Map<Id, Case> mapDirectCases = new Map<Id, Case>([SELECT Id FROM Case WHERE AccountId =: recordId]);
                whatIdSet.addAll(mapDirectCases.keySet());
            }
        }

        // Create a return List
        List<ActivityTimelineModel> lstAllActivities = new List<ActivityTimelineModel>();

        // Add Tasks, Emails & Events
        addTasksAndEmails(lstAllActivities, recordId, whatIdSet, whoIdSet,taskIdSet);
        addEvents(lstAllActivities, recordId, whatIdSet, whoIdSet,eventIdSet);
            
        return generateGroups(lstAllActivities);
    }

    private static List<ActivityTimelineGroup> generateGroups(List<ActivityTimelineModel> lstAllActivities) {
        // Sort List
        lstAllActivities.sort();

        //Filter Out Open Tasks & Activties
        List<ActivityTimelineModel> lstOpenActivities = new List<ActivityTimelineModel>();
        for(ActivityTimelineModel item : lstAllActivities){
            if(!item.isComplete){
                lstOpenActivities.add(item);
            }
        }

        //Prepare Map of grouped activities
        Map<Long, List<ActivityTimelineModel>> mapActivityTimeline = new Map<Long, List<ActivityTimelineModel>>();
        for(ActivityTimelineModel item : lstAllActivities){
            //Only Completed items
            if(item.isComplete){
                List<ActivityTimelineModel> lstActivities = new List<ActivityTimelineModel>();
                DateTime firstDayOfMonth = Datetime.newInstance(item.activityDate.year(), item.activityDate.month(), 1, 0, 0, 0);
                Long mapKey = firstDayOfMonth.getTime();
                if(mapActivityTimeline.containsKey(mapKey)){
                    lstActivities = mapActivityTimeline.get(mapKey);
                }

                lstActivities.add(item);
                mapActivityTimeline.put(mapKey, lstActivities);
            }
        }

        List<ActivityTimelineGroup> lstActivityGroups = new List<ActivityTimelineGroup>();
        //Open Activities
        lstActivityGroups.add(new ActivityTimelineGroup(System.Label.Upcoming_Overdue, lstOpenActivities));

        //Closed Activities
        For(Long dateAsLong: mapActivityTimeline.keySet()){
            ActivityTimelineGroup activityGroup = new ActivityTimelineGroup(dateAsLong, mapActivityTimeline.get(dateAsLong));
            lstActivityGroups.add(activityGroup);
        }
        
        return lstActivityGroups;
    }
    
    
    private static void addTasksAndEmails(List<ActivityTimelineModel> returnList, Id recordId, Set<Id> whatIdSet, Set<Id> whoIdSet,Set<Id> taskIdSet) {
        List<Task> taskList = [SELECT Id, ActivityDate, Description, IsRecurrence, OwnerId, Owner.Name, Priority, Status, Subject, 
                               				TaskSubtype, Type, WhatId, What.Name, WhoId, Who.Name
                               	FROM Task
                               	WHERE WhatId IN: whatIdSet OR WhoId IN: whoIdSet OR Id IN:taskIdSet
                               		ORDER BY ActivityDate DESC NULLS LAST];

        //generate a map of Task Status to get Closed Status
        Map<String, TaskStatus> mapTaskStatus = new Map<String, TaskStatus>();
		for(TaskStatus ts: [SELECT MasterLabel, IsClosed FROM TaskStatus]){
            mapTaskStatus.put(ts.MasterLabel, ts);
		}
        
        //generate a map of Task Priority to get High Priority
        Map<String, TaskPriority> mapTaskPriority = new Map<String, TaskPriority>();
		for(TaskPriority tp: [SELECT MasterLabel, IsHighPriority FROM TaskPriority]){
            mapTaskPriority.put(tp.MasterLabel, tp);
		}

        //generate a map of Email tasks
        //The Enhanced Emails are stored in the Email Message object but they have a corresponding Task with SubType Email.
        //You need to filter those out in order to prevent duplicate records being displayed
        Map<Id, Task> mapEmailTasks = new Map<Id, Task>();
        
        if(taskList.size() > 0) {
            for(Task taskObj: taskList) {
                if(taskObj.TaskSubtype == 'Email'){
                    //Collect tasks for handling email messages separately
                    mapEmailTasks.put(taskObj.Id, taskObj);
                } else {
                    ActivityTimelineModel taskItem = new ActivityTimelineModel();
                    
                    taskItem.recordId = taskObj.Id;
                    taskItem.sobjectName = String.valueOf(Task.SobjectType);
                    taskItem.activityTimelineType = taskObj.TaskSubtype;
                    taskItem.activityDate = taskObj.ActivityDate;
                    taskItem.subject = taskObj.Subject;
                    taskItem.detail = taskObj.Description;

                    //Assigned To
                    taskItem.assignedTo = new ActivityTimelineModel.RecordReference(taskObj.OwnerId, taskObj.Owner.Name);

                    //Recipients
                    if(String.isNotEmpty(taskObj.WhoId)){
                        //Dont add the current record in Task Contact
                        if(taskObj.WhoId != recordId){
                            taskItem.recipients = new List<ActivityTimelineModel.RecordReference>();
                            taskItem.recipients.add(new ActivityTimelineModel.RecordReference(taskObj.WhoId, taskObj.Who.Name));
                        }
                    }

                    //Related To
                    if(String.isNotEmpty(taskObj.WhatId)){
                        //Dont add the current record in related to
                        if(taskObj.WhatId != recordId){
                        	taskItem.relatedTo = new ActivityTimelineModel.RecordReference(taskObj.WhatId, taskObj.What.Name);
                        }
                    }

                    taskItem.isComplete = mapTaskStatus.get(taskObj.Status).IsClosed;
                    taskItem.isOverdue = taskObj.ActivityDate < Date.today() && !taskItem.isComplete;
                    taskItem.isRecurring = taskObj.IsRecurrence;
                    taskItem.isPriority = mapTaskPriority.get(taskObj.Priority).IsHighPriority;

                    returnList.add(taskItem);
                }
            }

            //Process Email Tasks
            if(mapEmailTasks.size() > 0) {
                List<EmailMessage> lstEmailMessages = [SELECT Id, ActivityId, HasAttachment, MessageDate, Status, Subject, TextBody,
                                                       		(SELECT Id, RelationType, RelationId, Relation.Name, RelationAddress
                                                            	FROM EmailMessageRelations)
                                                       	FROM EmailMessage
                                                       	WHERE ActivityId IN: mapEmailTasks.keySet()];
                For(EmailMessage emailMsg : lstEmailMessages){
                    Task taskObj = mapEmailTasks.get(emailMsg.ActivityId);

                    ActivityTimelineModel emailItem = new ActivityTimelineModel();
                    
                    emailItem.recordId = emailMsg.Id;
                    emailItem.sobjectName = String.valueOf(EmailMessage.SobjectType);
                    emailItem.activityTimelineType = 'Email';
                    emailItem.activityDate = emailMsg.MessageDate;
                    emailItem.subject = emailMsg.Subject;
                    emailItem.detail = emailMsg.TextBody;
                    
                    //Assigned To & Recipients
                    emailItem.recipients = new List<ActivityTimelineModel.RecordReference>();
                    For(EmailMessageRelation relationObj : emailMsg.EmailMessageRelations){
                        //Assigned To
                        if(relationObj.RelationType == 'FromAddress'){
                            if(String.isNotEmpty(relationObj.relationId)){
                                emailItem.assignedTo = new ActivityTimelineModel.RecordReference(relationObj.relationId, relationObj.Relation.Name);
                            } else {
                                emailItem.fromEmail = new ActivityTimelineModel.EmailReference(relationObj.RelationAddress);
                            }
                        } else if(relationObj.RelationType == 'ToAddress'){
                            if(String.isNotEmpty(relationObj.relationId)){
                                emailItem.recipients.add(new ActivityTimelineModel.RecordReference(relationObj.relationId, relationObj.Relation.Name));
                            } else {
                                emailItem.toEmail = new ActivityTimelineModel.EmailReference(relationObj.RelationAddress);
                            }
                        }
                    }

                    //Related To
                    if(String.isNotEmpty(taskObj.WhatId)){
                        //Dont add the current record in Related To
                        if(taskObj.WhatId != recordId){
                        	emailItem.relatedTo = new ActivityTimelineModel.RecordReference(taskObj.WhatId, taskObj.What.Name);
                        }
                    }

                    emailItem.isComplete = true;
                    emailItem.hasAttachments = emailMsg.HasAttachment;

                    returnList.add(emailItem);
                }
            }
        }
    }

    private static void addEvents(List<ActivityTimelineModel> returnList, Id recordId, Set<Id> whatIdSet, Set<Id> whoIdSet,Set<Id> eventIdSet) {
        List<Event> eventList = [SELECT Id, ActivityDate, Description, EndDateTime, EventSubtype, IsRecurrence, OwnerId, Owner.Name, 
                                 		StartDateTime, Subject, Type, WhatId, What.Name, WhoId, Who.Name
                                	FROM Event
                                	WHERE WhatId IN: whatIdSet OR WhoId IN: whoIdSet OR Id IN: eventIdSet];
        
        if(eventList.size() > 0) {
            for(Event eventObj: eventList) {
                ActivityTimelineModel eventItem = new ActivityTimelineModel();
                
                eventItem.recordId = eventObj.Id;
                eventItem.sobjectName = String.valueOf(Event.SobjectType);
                eventItem.activityTimelineType = 'Event';
                eventItem.activityDate = eventObj.ActivityDate;
                eventItem.subject = eventObj.Subject;
                eventItem.detail = eventObj.Description;

                //Assigned To
                eventItem.assignedTo = new ActivityTimelineModel.RecordReference(eventObj.OwnerId, eventObj.Owner.Name);

                //Recipients
                if(String.isNotEmpty(eventObj.WhoId)){
                    if(eventObj.WhoId != recordId){
                        eventItem.recipients = new List<ActivityTimelineModel.RecordReference>();
                        eventItem.recipients.add(new ActivityTimelineModel.RecordReference(eventObj.WhoId, eventObj.Who.Name));
                    }
                }

                //Related To
                if(String.isNotEmpty(eventObj.WhatId)){
                    if(eventObj.WhatId != recordId){
                    	eventItem.relatedTo = new ActivityTimelineModel.RecordReference(eventObj.WhatId, eventObj.What.Name);
                    }
                }

                eventItem.startDateTime = eventObj.StartDateTime;
                eventItem.endDateTime = eventObj.EndDateTime;
                eventItem.isComplete = eventObj.StartDateTime < System.now();

                returnList.add(eventItem);
            }
        }
    }
}