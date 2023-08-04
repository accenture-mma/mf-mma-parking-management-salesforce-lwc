import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCombinedData from '@salesforce/apex/CustomObjectController.getCombinedData';
import createReservation from '@salesforce/apex/CustomObjectController.reserveSlot';
import cancelReservation from '@salesforce/apex/CustomObjectController.cancelSlot';
import releaseSlot from '@salesforce/apex/CustomObjectController.releaseSlot';
import myImageResource from '@salesforce/resourceUrl/mmaParkingLogo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

const ADMIN_PROFILE_API_NAME = 'MMA Admin User';
const FIELDS = [
    'User.Name',
    'User.Email',
    'User.Title',
    'User.Profile.Name'
];

export default class CustomObjectComponent extends LightningElement {
    
    isAdmin = false;
    userRecord;

    imageUrl = myImageResource;
    carCount;
    showForm;
    @track slotStartTime;
    @track slotEndTime;
    @track slotId;
    @track carNumber;
    @track emailId;
    @track phoneNumber;

    @wire(getCombinedData) 
    wiredData;

    handleRefresh() {
        refreshApex(this.wiredData);
        getCombinedData()
        .then(result => {
            this.carCount = (result.filter(item => item.carNumber != null)).length;
        })
    }

    connectedCallback() {
        refreshApex(this.wiredData);
        getCombinedData()
        .then(result => {
            this.carCount = (result.filter(item => item.carNumber != null)).length;
        })
    }

    handleReleaseSlotButtonClick(){
        releaseSlot({slotId: event.target.dataset.id})
        .then(result => {
            this.showSuccessToast('Success', 'Slot released successful', 'success');
            refreshApex(this.wiredData);
        })
        .catch(error => {
            let e = (error.body.message ? error.body.message : error.body.pageErrors[0].message ? error.body.pageErrors[0].message : '');
            this.showSuccessToast('Error', 'Slot release failed: '  + (e), 'error');
            console.error("Error in creating reservation: ", error);
        })
    }

    handleCancelSlotButtonClick(){
        cancelReservation({slotId: event.target.dataset.id})
        .then(result => {
            this.showSuccessToast('Success', 'Slot cancellation successful', 'success');
            refreshApex(this.wiredData);
        })
        .catch(error => {
            let e = (error.body.message ? error.body.message : error.body.pageErrors[0].message ? error.body.pageErrors[0].message : '');
            this.showSuccessToast('Error', 'Slot cancellation failed: '  + (e), 'error');
            console.error("Error in creating reservation: ", error);
        })
    }

    handleBookSlotButtonClick() {
        this.slotId = event.target.dataset.id;
        this.showForm = true;
    }

    hideModalBox(){
        this.showForm = false;
    }

    handleStartDateTimeChange() {
        this.slotStartTime = event.target.value;
    }

    handlePhoneNumberChange() {
        this.phoneNumber = event.target.value;
    }

    handleEndDateTimeChange() {
        this.slotEndTime = event.target.value;
    }

    handleCarNumberChange() {
        this.carNumber = event.target.value;
    }

    handleSubmit() {
        createReservation({slotId:this.slotId, slotStartTime: this.slotStartTime, slotEndTime: this.slotEndTime, carNumber: this.carNumber, emailId: this.emailId, phoneNumber: this.phoneNumber})
        .then(result => {
            this.showSuccessToast('Success', 'Slot reservation successful', 'success');
            refreshApex(this.wiredData);
            console.log(result);
        })
        .catch(error => {
            let e = (error.body.message ? error.body.message : error.body.pageErrors[0].message ? error.body.pageErrors[0].message : '');
            this.showSuccessToast('Error', 'Slot reservation failed: ' + (e), 'error');
            console.error("Error in creating reservation: ", error);
        })
        this.resetForm();
    }

    resetForm() {
        this.slotStartTime = '';
        this.slotEndTime = '';
        this.carNumber= '';
        this.showForm = false;
    }

    showSuccessToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);

        setTimeout(() => {
            this.dispatchEvent(new ShowToastEvent({ variant: variant, message: message, title: title }));
        }, 5000);
    }

    @wire(getRecord, { recordId: USER_ID, fields: FIELDS })
    wireUser({ error, data }) {
        if (data) {
            this.userRecord = data;
            this.isAdmin = getFieldValue(this.userRecord, 'User.Profile.Name') === ADMIN_PROFILE_API_NAME;
        } else if (error) {
            // Handle the error, if any
            console.error('Error fetching user data:', error);
        }
    }
}
