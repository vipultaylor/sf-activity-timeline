import { LightningElement, api, track } from 'lwc';
import getActivityTimeline from '@salesforce/apex/ActivityTimelineController.getActivityTimeline';
import getUserTimeZoneId from '@salesforce/apex/ActivityTimelineController.getUserTimeZoneId';

export default class ActivityTimeline extends LightningElement {
    @api recordId;
    @api includeChildren;

    @track timelineGroups = [];
    @track activeSections = [];
    @track isLoading = false;
    @track userTzId;

    connectedCallback() {
        this.loadTimeline();
        getUserTimeZoneId()
            .then((tz) => {
                this.userTzId = tz;
            })
            .catch((error) => {
                console.error('Error fetching user tz', error);
            });
    }

    async loadTimeline() {
        this.isLoading = true;
        try {
            const data = await getActivityTimeline({
                recordId: this.recordId,
                includeChildren: this.includeChildren
            });

            // Add section names & open them all by default
            const groups = data.map((group, index) => {
                return { ...group, sectionName: `Section${index}` };
            });

            this.timelineGroups = groups;
            this.activeSections = groups.map((group) => group.sectionName);
        } catch (error) {
            console.error('Error loading activity timeline:', error);
        } finally {
            this.isLoading = false;
        }
    }
}
