public with sharing class CustomObjectController {
    @AuraEnabled(cacheable=true)
    public static List<CombinedDataWrapper> getCombinedData() {
        List<CombinedDataWrapper> combinedDataList = new List<CombinedDataWrapper>();

        // Query Object1__c
        List<parking_slot__c> parkingSlotList = [select Id, Name, slot_identifier__c, slotOccupied__c, slot_reserved__c from parking_slot__c order by slot_identifier__c asc];
        
        // Query Object2__c
        List<parking__c> parkingList = [Select Id, inDateTime__c, outDateTime__c, carNumber__c, parking_slot__c  from parking__c];

        List<parking_slot_reservation__c> parkingReservationList = [SELECT Id, slot_start_time__c, slot_end_time__c, parking_slot__c, carNumber__c  FROM parking_slot_reservation__c];

        // Combine the data
        for (parking_slot__c parkingSlot : parkingSlotList) {
            CombinedDataWrapper combinedData = new CombinedDataWrapper();
            combinedData.Id = parkingSlot.Id;
            combinedData.slotOccupied = parkingSlot.slotOccupied__c;
            combinedData.slotReserved = parkingSlot.slot_reserved__c;
            combinedData.slotIdentifier = parkingSlot.slot_identifier__c;
            combinedData.cssClassName = parkingSlot.slotOccupied__c ? 'box red' : parkingSlot.slot_reserved__c ? 'box orange': 'box green';
            combinedData.carNumber = getparkingData(parkingList, parkingSlot.Id) == null ? null : getparkingData(parkingList, parkingSlot.Id).carNumber__c;
            combinedData.carInTime = getparkingData(parkingList, parkingSlot.Id) == null ? null : getparkingData(parkingList, parkingSlot.Id).inDateTime__c;
            combinedData.carOutTime = getparkingData(parkingList, parkingSlot.Id) == null ? null : getparkingData(parkingList, parkingSlot.Id).outDateTime__c;
            combinedData.reservationStartTime = getparkingReservationData(parkingReservationList, parkingSlot.Id) == null ? null : getparkingReservationData(parkingReservationList, parkingSlot.Id).slot_start_time__c;
            combinedData.reservationEndTime = getparkingReservationData(parkingReservationList, parkingSlot.Id) == null ? null : getparkingReservationData(parkingReservationList, parkingSlot.Id).slot_end_time__c; 
            combinedData.reservedCarNumber = getparkingReservationData(parkingReservationList, parkingSlot.Id) == null ? null : getparkingReservationData(parkingReservationList, parkingSlot.Id).carNumber__c;            
            combinedDataList.add(combinedData);
        }

        return combinedDataList;
    }

    @AuraEnabled
    public static String reserveSlot(Id slotId, DateTime slotStartTime, Datetime slotEndTime, String carNumber, String phoneNumber) {
        parking_slot_reservation__c reservation = new parking_slot_reservation__c();
        reservation.parking_slot__c = slotId;
        reservation.slot_start_time__c = slotStartTime;
        reservation.slot_end_time__c = slotEndTime;
        reservation.carNumber__c = carNumber;
        reservation.Phone_Number__c = phoneNumber;
        
        String accountSid = 'ACc06e5bca852edbbb687fe7f9b7499901';
        String authToken = '8d7d40ba7b73e96e51e1f0c0979a2aff';
        parking_slot__c parkingSlot = [Select slot_identifier__c from parking_slot__c where Id = :slotId];
        
        String endpoint = 'https://api.twilio.com/2010-04-01/Accounts/' + accountSid + '/Messages.json';
        
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(endpoint);
        
        request.setMethod('POST');
        
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(accountSid + ':' + authToken)));
        
        String body = 'You booking for car number ' + carNumber + ' is confirmed in slot number '+ parkingSlot.slot_identifier__c +' at ' + slotStartTime;

        String requestBody = 'To=whatsapp:' + EncodingUtil.urlEncode(phoneNumber, 'UTF-8') + '&From=whatsapp:' + EncodingUtil.urlEncode('+14155238886','UTF-8') + '&Body=' + body;
        request.setBody(requestBody);
        
        Http http = new Http();
        
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 201) {
            String responseBody = response.getBody();
            Insert reservation;
            return 'SMS Sent Successfully';
        } else {
            errorWrapper er = (errorWrapper)json.deserialize(response.getBody(), errorWrapper.class);
            throw newMessageException('Error : ' + er.message);
        }        
    }

    @AuraEnabled
    public static void cancelSlot(Id slotId) {
        parking_slot_reservation__c[] parkingReservation = [SELECT Id FROM parking_slot_reservation__c WHERE parking_slot__c = :slotId];
        parking_slot__c parkingSlot = new parking_slot__c();
        parkingSlot.slot_reserved__c = false;
        parkingSlot.Id = slotId;
        delete parkingReservation;
        update parkingSlot;
    }

    @AuraEnabled
    public static void releaseSlot(Id slotId) {
        parking__c[] parking = [SELECT Id FROM parking__c WHERE parking_slot__c = :slotId];
        parking_slot__c parkingSlot = new parking_slot__c();
        parkingSlot.slotOccupied__c = false;
        parkingSlot.Id = slotId;
        delete parking;
        update parkingSlot;
    }

    // Helper method to find corresponding Object2__c record
    private static parking__c getparkingData(List<parking__c> parkingList, Id parkingSlotId) {
        for (parking__c parking : parkingList) {
            if (parking.parking_slot__c == parkingSlotId) {
                return parking;
            }
        }
        return null;
    }

    private static parking_slot_reservation__c getparkingReservationData(List<parking_slot_reservation__c> parkingReservationList, Id parkingSlotId) {
        for (parking_slot_reservation__c parkingReservation : parkingReservationList) {
            if (parkingReservation.parking_slot__c == parkingSlotId) {
                return parkingReservation;
            }
        }
        return null;
    }

    // Wrapper class to hold combined data
    public class CombinedDataWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public Boolean slotOccupied;
        @AuraEnabled public Boolean slotReserved;
        @AuraEnabled public String slotIdentifier;
        @AuraEnabled public String carNumber;
        @AuraEnabled public Datetime carInTime;
        @AuraEnabled public Datetime carOutTime;
        @AuraEnabled public String cssClassName;
        @AuraEnabled public Datetime reservationStartTime;
        @AuraEnabled public Datetime reservationEndTime;
        @AuraEnabled public String reservedCarNumber;
    }

    public class errorWrapper{
        String code;
        String message;
        String moreInfo;
        String status; 
    }

    private static AuraHandledException newMessageException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
