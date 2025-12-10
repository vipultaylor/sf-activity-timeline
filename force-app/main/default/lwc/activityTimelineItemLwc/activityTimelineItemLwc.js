import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateTaskStatus from '@salesforce/apex/ActivityTimelineController.updateTaskStatus';

export default class ActivityTimelineItem extends LightningElement {
    @api item;
    @api currentUserTimezone;
    @api isExpanded = false;
    @track isModalOpen = false;
    @track statusOptions = [];
    @track selectedStatus;
    toggleActivityDetail = () => {
        this.isExpanded = !this.isExpanded;
    };
    handleTaskCheckboxChange(event) {
        const checked = event.target.checked;
        if (checked) {
            this.statusOptions = [
                { label: 'Completed', value: 'Completed' },
                { label: 'Not Completed', value: 'Not Completed' },
                { label: 'Closed-Not Conducted', value: 'Closed-Not Conducted' },
                { label: 'Closed-Not Transferred', value: 'Closed-Not Transferred' },
                { label: 'Closed-Transferred', value: 'Closed-Transferred' },
                { label: 'Closed', value: 'Closed' }
            ];
        } else {
            this.statusOptions = [
                { label: 'Not Started', value: 'Not Started' },
                { label: 'Attempted', value: 'Attempted' }
            ];
        }

        this.isModalOpen = true;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedStatus = null;
    }

    get saveDisabled() {
        if (this.selectedStatus) {
            return false;
        } else {
            return true;
        }
    }

    async saveStatus() {
        updateTaskStatus({
            itemId: this.item.recordId,
            selectedStatus: this.selectedStatus
        })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Record updated',
                        variant: 'success'
                    })
                );
            })
            .catch((e) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating record',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
                console.error(JSON.stringify(e));
            })
            .finally(() => {
                this.isModalOpen = false;
            });
    }
    // --- IDs & labels ---
    get detailsId() {
        // stable, unique id for aria-controls
        return `details-${this.item?.recordId || 'x'}`;
    }
    get checkboxId() {
        return `cb-${this.item?.recordId || 'x'}`;
    }
    get subjectLabel() {
        return this.item?.subject || 'Untitled';
    }
    // --- Container classes & ARIA ---
    get containerClass() {
        const base = ['slds-timeline__item_expandable', 'slds-p-bottom_x-small'];
        switch (this.item?.activityTimelineType) {
            case 'Call':
                base.push('slds-timeline__item_call');
                break;
            case 'Email':
                base.push('slds-timeline__item_email');
                break;
            case 'Event':
                base.push('slds-timeline__item_event');
                break;
            default:
                base.push('slds-timeline__item_task');
        }
        if (this.isExpanded) base.push('slds-is-open');
        return base.join(' ');
    }
    get detailsAriaHidden() {
        // aria-hidden mirrors the collapsed state
        return this.isExpanded ? 'false' : 'true';
    }
    get toggleTitle() {
        return `Toggle details for ${this.item?.subject || 'activity'}`;
    }

    // --- URLs (only used when the related UI shows) ---
    get recordUrl() {
        if (!this.item?.sobjectName || !this.item?.recordId) return null;
        return `/lightning/n/CustomRecordPage?c__recordId=${this.item.recordId}`;
    }
    get assignedToUrl() {
        const a = this.item?.assignedTo;
        if (!a?.sobjectName || !a?.recordId) return null;
        return `/lightning/r/${a.sobjectName}/${a.recordId}/view`;
    }
    get firstRecipientUrl() {
        const r = this.item?.recipients?.[0];
        if (!r?.sobjectName || !r?.recordId) return null;
        return `/lightning/r/${r.sobjectName}/${r.recordId}/view`;
    }
    get relatedToUrl() {
        const r = this.item?.relatedTo;
        if (!r?.sobjectName || !r?.recordId) return null;
        return `/lightning/r/${r.sobjectName}/${r.recordId}/view`;
    }

    // --- Styling helpers ---
    get dateClass() {
        return this.item?.isOverdue ? 'slds-timeline__date slds-text-color_error' : 'slds-timeline__date';
    }

    // --- Type checks ---
    get isTask() {
        return this.item?.activityTimelineType === 'Task';
    }
    get isCall() {
        return this.item?.activityTimelineType === 'Call';
    }
    get isEmail() {
        return this.item?.activityTimelineType === 'Email';
    }
    get isEvent() {
        return this.item?.activityTimelineType === 'Event';
    }

    // --- Display rules ---
    get showTimeForActivity() {
        // Time not shown for Task/Call
        const t = this.item?.activityTimelineType;
        return t !== 'Task' && t !== 'Call';
    }
    get showTaskCheckbox() {
        return this.isTask && !this.item?.isComplete;
    }
    get hasMultipleRecipients() {
        return (this.item?.recipients?.length || 0) > 1;
    }
    get additionalRecipientsCount() {
        return Math.max(0, (this.item?.recipients?.length || 0) - 1);
    }
    get additionalRecipientsText() {
        return this.item?.recipients?.length === 2 ? 'other' : 'others';
    }

    // --- Byline phrasing ---
    get activityTenseText() {
        const type = this.item?.activityTimelineType;
        if (!type) return '';
        if (this.item?.isComplete) {
            switch (type) {
                case 'Task':
                    return ' had a task ';
                case 'Call':
                    return ' logged a call ';
                case 'Email':
                    return ' sent an email ';
                case 'Event':
                    return ' had an event ';
                default:
                    return '';
            }
        } else {
            const hasHave = this.item?.assignedTo?.isCurrentUser ? ' have' : ' has';
            switch (type) {
                case 'Task':
                    return `${hasHave} an upcoming task`;
                case 'Call':
                    return `${hasHave} an upcoming call`;
                case 'Event':
                    return `${hasHave} an upcoming event`;
                default:
                    return '';
            }
        }
    }
    get relationshipPreposition() {
        return this.item?.activityTimelineType === 'Email' ? ' to ' : ' with ';
    }

    // --- Visibility switches ---
    get showAssignedTo() {
        return !!this.item?.assignedTo;
    }
    get showFromEmail() {
        return !this.item?.assignedTo && !!this.item?.fromEmail?.address;
    }
    get showRecipients() {
        return !!(this.item?.recipients && this.item.recipients.length);
    }
    get showToEmail() {
        return !!this.item?.toEmail?.address;
    }
    get showRelatedTo() {
        return !!this.item?.relatedTo?.recordName;
    }

    // --- Convenience getters for template ---
    get isAssignedToCurrentUser() {
        return !!this.item?.assignedTo?.isCurrentUser;
    }
    get isFirstRecipientCurrentUser() {
        return !!this.item?.recipients?.[0]?.isCurrentUser;
    }

    get assignedToRecordName() {
        return this.item?.assignedTo?.recordName || '';
    }
    get fromEmailAddress() {
        return this.item?.fromEmail?.address || '';
    }
    get firstRecipientName() {
        return this.item?.recipients?.[0]?.recordName || '';
    }
    get toEmailAddress() {
        return this.item?.toEmail?.address || '';
    }
    get relatedToRecordName() {
        return this.item?.relatedTo?.recordName || '';
    }
}
