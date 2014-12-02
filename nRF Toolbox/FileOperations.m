//
//  FileOperations.m
//  nRF Toolbox
//
//  Created by Kamran Saleem Soomro on 03/07/14.
//  Copyright (c) 2014 Nordic Semiconductor. All rights reserved.
//

#import "FileOperations.h"
#import "IntelHex2BinConverter.h"
#import "Utility.h"

@implementation FileOperations

-(FileOperations *) initWithDelegate:(id<FileOperationsDelegate>) delegate blePeripheral:(CBPeripheral *)peripheral bleCharacteristic:(CBCharacteristic *)dfuPacketCharacteristic;
{
    self = [super init];
    if (self)
    {
        self.fileDelegate = delegate;
        self.bluetoothPeripheral = peripheral;
        self.dfuPacketCharacteristic = dfuPacketCharacteristic;
    }
    return self;
}

-(void)openFile:(NSURL *)fileURL
{
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if (fileData.length > 0) {
        [self processFileData:fileURL];
        [self.fileDelegate onFileOpened:self.binFileSize];
    }
    else {
        NSLog(@"Error: file is empty!");
        NSString *errorMessage = [NSString stringWithFormat:@"Error on openning file\n Message: file is empty or not exist"];
        [self.fileDelegate onError:errorMessage];
    }
}

-(BOOL)isFileExtension:(NSString *)fileName fileExtension:(enumFileExtension)fileExtension
{
    if ([[fileName pathExtension] isEqualToString:[Utility stringFileExtension:fileExtension]]) {
        return YES;
    }
    else {
        return NO;
    }
}

-(void)processFileData:(NSURL *)fileURL
{
    NSString *fileName = [[fileURL path] lastPathComponent];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if ([self isFileExtension:fileName fileExtension:HEX]) {
        self.binFileData = [IntelHex2BinConverter convert:fileData];
        NSLog(@"HexFileSize: %lu and BinFileSize: %lu",(unsigned long)fileData.length,(unsigned long)self.binFileData.length);
    }
    else if ([self isFileExtension:fileName fileExtension:BIN]) {
        self.binFileData = [NSData dataWithContentsOfURL:fileURL];
        NSLog(@"BinFileSize: %lu",(unsigned long)self.binFileData.length);
    }
    self.numberOfPackets = ceil((double)self.binFileData.length / (double)PACKET_SIZE);
    self.bytesInLastPacket = (self.binFileData.length % PACKET_SIZE);
    if (self.bytesInLastPacket == 0) {
        self.bytesInLastPacket = PACKET_SIZE;
    }
    NSLog(@"Number of Packets %d Bytes in last Packet %d",self.numberOfPackets,self.bytesInLastPacket);
    self.writingPacketNumber = 0;
    self.binFileSize = self.binFileData.length;
}

/*-(void)convertHexFileToBin:(NSData *)hexFileData
{
    self.binFileData = [IntelHex2BinConverter convert:hexFileData];
    NSLog(@"HexFileSize: %lu and BinFileSize: %lu",(unsigned long)hexFileData.length,(unsigned long)self.binFileData.length);
    self.numberOfPackets = ceil((double)self.binFileData.length / (double)PACKET_SIZE);
    self.bytesInLastPacket = (self.binFileData.length % PACKET_SIZE);
    if (self.bytesInLastPacket == 0) {
        self.bytesInLastPacket = PACKET_SIZE;
    }
    NSLog(@"Number of Packets %d Bytes in last Packet %d",self.numberOfPackets,self.bytesInLastPacket);
    self.writingPacketNumber = 0;
    self.binFileSize = self.binFileData.length;

}*/

-(void)writeNextPacket
{
    int percentage = 0;
    for (int index = 0; index<PACKETS_NOTIFICATION_INTERVAL; index++) {
        if (self.writingPacketNumber > self.numberOfPackets-2) {
            NSLog(@"writing last packet");
            NSRange dataRange = NSMakeRange(self.writingPacketNumber*PACKET_SIZE, self.bytesInLastPacket);
            NSData *nextPacketData = [self.binFileData subdataWithRange:dataRange];
            NSLog(@"writing packet number %d ...",self.writingPacketNumber+1);
            NSLog(@"packet data: %@",nextPacketData);
            [self.bluetoothPeripheral writeValue:nextPacketData forCharacteristic:self.dfuPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
            self.writingPacketNumber++;
            [self.fileDelegate onAllPacketsTranferred];            
            break;
        }
        NSRange dataRange = NSMakeRange(self.writingPacketNumber*PACKET_SIZE, PACKET_SIZE);
        NSData *nextPacketData = [self.binFileData subdataWithRange:dataRange];
        NSLog(@"writing packet number %d ...",self.writingPacketNumber+1);
        NSLog(@"packet data: %@",nextPacketData);
        [self.bluetoothPeripheral writeValue:nextPacketData forCharacteristic:self.dfuPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
        percentage = (((double)(self.writingPacketNumber * 20) / (double)(self.binFileSize)) * 100);
        [self.fileDelegate onTransferPercentage:percentage];
        self.writingPacketNumber++;        
    }

}

-(void)setBLEParameters:(CBPeripheral *)peripheral bleCharacteristic:(CBCharacteristic *)dfuPacketCharacteristic
{
    self.bluetoothPeripheral = peripheral;
    self.dfuPacketCharacteristic = dfuPacketCharacteristic;
}

@end
