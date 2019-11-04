@IsTest
private class ActivityTimelineControllerTest {
    private static integer TASK_COUNT = 5;
    private static integer CALL_COUNT = 5;
    private static integer EVENT_COUNT = 5;
    private static integer EMAIL_COUNT = 5;

    @testSetup static void setup(){
		//Insert Accounts
        List<Account> lstAccounts = new List<Account> {new Account(Name='Test Account 1', AccountNumber='A1', AnnualRevenue=12345.67)};
		insert lstAccounts;

        List<Contact> lstContacts = new List<Contact> {new Contact(LastName='Test Contact 1', AccountId=lstAccounts[0].Id)};
		insert lstContacts;

        List<Opportunity> lstOpportunities = new List<Opportunity> {new Opportunity(Name='Test Opportunity 1', AccountId=lstAccounts[0].Id, StageName='Prospecting', Amount=12345.67, CloseDate=Date.today().addDays(30))};
		insert lstOpportunities;

        //Insert Activities

        //Add Tasks
        List<Task> lstTasks = new List<Task>();
        lstTasks.addAll(addTasks(TASK_COUNT, 'Task', lstAccounts[0].Id, null));
        lstTasks.addAll(addTasks(TASK_COUNT, 'Task', lstOpportunities[0].Id, lstContacts[0].Id));
        lstTasks.addAll(addTasks(CALL_COUNT, 'Call', lstAccounts[0].Id, null));
        lstTasks.addAll(addTasks(CALL_COUNT, 'Call', lstOpportunities[0].Id, lstContacts[0].Id));
        insert lstTasks;

        //Add Events
        List<Event> lstEvents = new List<Event>();
        lstEvents.addAll(addEvents(EVENT_COUNT, lstAccounts[0].Id, null));
        lstEvents.addAll(addEvents(EVENT_COUNT, lstOpportunities[0].Id, lstContacts[0].Id));
        insert lstEvents;

        insertEmails(EMAIL_COUNT, lstAccounts[0].Id, null);
        insertEmails(EMAIL_COUNT, lstOpportunities[0].Id, lstContacts[0].Id);
	}
    
    @IsTest
    private static void testActivitiesForAccounts_IncludeChildren(){
        List<Account> lstAccounts = [SELECT Id FROM Account];

        Test.startTest();
        List<ActivityTimelineGroup> groups = ActivityTimelineController.getActivityTimeline(lstAccounts[0].Id, true);
        //Calculate the months for the closed task groupings
        //Add 1 to include the current month in calculations
        Integer maxCount = Math.max(Math.max(TASK_COUNT, CALL_COUNT), EMAIL_COUNT);
        Integer monthsForGrouping = Date.today().month() - Date.today().addDays(maxCount*-10).month() + 1;

        //Assert the groups size - add 1 for the upcoming tasks grouping
        System.assertEquals(monthsForGrouping + 1, groups.size());

        List<ActivityTimelineModel> lstActivities = new List<ActivityTimelineModel>();
        For(ActivityTimelineGroup groupObj : groups){
            lstActivities.addAll(groupObj.items);
        }
        System.assertEquals(TASK_COUNT*2 + CALL_COUNT*2 + EVENT_COUNT*2 + EMAIL_COUNT*2, lstActivities.size());

        Test.stopTest();
    }
    
    @IsTest
    private static void testActivitiesForAccounts_ExcludeChildren(){
        List<Account> lstAccounts = [SELECT Id FROM Account];

        Test.startTest();
        List<ActivityTimelineGroup> groups = ActivityTimelineController.getActivityTimeline(lstAccounts[0].Id, false);
        //Calculate the months for the closed task groupings
        //Add 1 to include the current month in calculations
        Integer maxCount = Math.max(Math.max(TASK_COUNT, CALL_COUNT), EMAIL_COUNT);
        Integer monthsForGrouping = Date.today().month() - Date.today().addDays(maxCount*-10).month() + 1;

        //Assert the groups size - add 1 for the upcoming tasks grouping
        System.assertEquals(monthsForGrouping + 1, groups.size());

        List<ActivityTimelineModel> lstActivities = new List<ActivityTimelineModel>();
        For(ActivityTimelineGroup groupObj : groups){
            lstActivities.addAll(groupObj.items);
        }
        System.assertEquals(TASK_COUNT + CALL_COUNT + EVENT_COUNT + EMAIL_COUNT, lstActivities.size());

        Test.stopTest();
    }

    @IsTest
    private static void testActivitiesForContacts(){
        List<Contact> lstContacts = [SELECT Id FROM Contact];

        Test.startTest();
        List<ActivityTimelineGroup> groups = ActivityTimelineController.getActivityTimeline(lstContacts[0].Id, true);
        //Calculate the months for the closed task groupings
        //Add 1 to include the current month in calculations
        Integer maxCount = Math.max(Math.max(TASK_COUNT, CALL_COUNT), EMAIL_COUNT);
        Integer monthsForGrouping = Date.today().month() - Date.today().addDays(maxCount*-10).month() + 1;

        //Assert the groups size - add 1 for the upcoming tasks grouping
        System.assertEquals(monthsForGrouping + 1, groups.size());

        List<ActivityTimelineModel> lstActivities = new List<ActivityTimelineModel>();
        For(ActivityTimelineGroup groupObj : groups){
            lstActivities.addAll(groupObj.items);
        }
        System.assertEquals(TASK_COUNT + CALL_COUNT + EVENT_COUNT, lstActivities.size());

        Test.stopTest();
    }
    
    private static List<Task> addTasks(Integer numberOfTasks, String subType, Id whatId, Id whoId){
        String closedStatus, openStatus;
        For(TaskStatus ts : [SELECT MasterLabel, IsClosed FROM TaskStatus]){
            if(ts.IsClosed){
                closedStatus = ts.MasterLabel;
            } else {
                openStatus = ts.MasterLabel;
            }
        }

        List<Task> lstTasks = new List<Task>();
        For(Integer i=0; i<numberOfTasks; i++){
            Task newTask = new Task(
                Subject = 'Test Subject (' + subType + ') ' + i, 
                TaskSubType = subType,
                ActivityDate = Date.today().addDays(i*-10),
                Description = 'Test Description ' + i,
				Status = Math.mod(i, 2) == 0 ? closedStatus : openStatus
            );
            
            if(whatId != null){
                newTask.WhatId = whatId;
            }
            if(whoId != null){
                newTask.WhoId = whoId;
            }
            
            lstTasks.add(newTask);
		}
        
        return lstTasks;
    }

    private static List<Event> addEvents(Integer numberOfEvents, Id whatId, Id whoId){
        List<Event> lstEvents = new List<Event>();
        For(Integer i=0; i<numberOfEvents; i++){
            Event newEvent = new Event(
                Subject = 'Test Event ' + i, 
                EventSubType = 'Event',
                StartDateTime = System.now(),
                EndDateTime = System.now().addHours(1),
                Description = 'Test Description ' + i
            );
            
            if(whatId != null){
                newEvent.WhatId = whatId;
            }
            if(whoId != null){
                newEvent.WhoId = whoId;
            }
            
            lstEvents.add(newEvent);
		}
        
        return lstEvents;
    }

    private static void insertEmails(Integer numberOfEmails, Id whatId, Id whoId){
        List<EmailMessage> lstEmails = new List<EmailMessage>();
        For(Integer i=0; i <numberOfEmails; i++){
            EmailMessage newEmail = new EmailMessage(
                RelatedToId = whatId,
                MessageDate = Date.today().addDays(i*-10),
                Subject = 'Test Email ' + i, 
                TextBody = 'Test Description ' + i,
                FromName = UserInfo.getName(),
                FromAddress = UserInfo.getUserEmail(),
                ToAddress = UserInfo.getUserEmail()
            );
            
            lstEmails.add(newEmail);
		}
        Database.insert(lstEmails);

        List<EmailMessageRelation> lstRelations = new List<EmailMessageRelation>();
        For(EmailMessage emailObj : lstEmails){
            EmailMessageRelation fromRelationObj = new EmailMessageRelation(
                EmailMessageId = emailObj.Id,
                RelationType = 'FromAddress',
                RelationId = whoId,
                RelationAddress = UserInfo.getUserEmail()
            );
            lstRelations.add(fromRelationObj);

            EmailMessageRelation toRelationObj = new EmailMessageRelation(
                EmailMessageId = emailObj.Id,
                RelationType = 'ToAddress',
                RelationId = whoId,
                RelationAddress = UserInfo.getUserEmail()
            );
            lstRelations.add(toRelationObj);
        }

        Database.insert(lstRelations);
    }

}