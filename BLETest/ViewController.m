//
//  ViewController.m
//  BLETest
//
//  Created by Realank on 2017/1/19.
//  Copyright © 2017年 iMooc. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface NSMutableArray (PrintArray)

- (NSString *)description;
@end

@implementation NSMutableArray (PrintArray)

- (NSString *)description{
    NSString* content = @"";
    NSArray* copyOne = [self copy];
    for (id item in copyOne) {
        content = [content stringByAppendingString:[NSString stringWithFormat:@"[%@]",[item description]]];
    }
    return content;
}

@end

@interface ViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *connectStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *sendStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *receiveStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *missStatusLabel;
@property (weak, nonatomic) IBOutlet UITextField *packageNumTF;
@property (weak, nonatomic) IBOutlet UITextField *packageIntervalTF;
@property (weak, nonatomic) IBOutlet UITextView *logTextView;
@property (weak, nonatomic) IBOutlet UISwitch *sendButton;

@property (nonatomic, strong) CBCentralManager* centralManager;
@property (nonatomic, strong) NSMutableArray* missedPackageArray;
@property (nonatomic, strong) CBPeripheral* discoveredDevice;
@property (nonatomic, strong) CBPeripheral* connectedDevice;
@property (nonatomic, assign) NSInteger packageNumToSend;
@property (nonatomic, assign) NSInteger packageSendInterval;
@property (nonatomic, strong) CBCharacteristic* sendCharacteristic;

@property (nonatomic, strong) NSTimer* sendTimer;

@property (nonatomic, assign) NSInteger packageLength;
@property (nonatomic, assign) NSInteger packageIndex;

//rcv
@property (nonatomic, assign) NSInteger rcvCount;
@property (nonatomic, strong) NSMutableArray* rcvArr;
@property (nonatomic, strong) NSMutableArray* missArr;

@property (nonatomic, strong) CADisplayLink* displayLink;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _packageNumToSend = 10;
    _packageSendInterval = 1000;//ms
    [self initUI];
    [self initBTManager];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateUI)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)updateUI{
    _receiveStatusLabel.text = [NSString stringWithFormat:@"Rcv count:%ld",(long)_rcvCount];
    if (_rcvCount == 0) {
        _logTextView.text = @"";
    }
    self.logTextView.text = [NSString stringWithFormat:@"Rcv:%@",[self.rcvArr description]];
    self.missStatusLabel.text = [NSString stringWithFormat:@"Miss:%@",[self.missArr description]];
}

- (void)initBTManager{
    
    dispatch_queue_t queue = dispatch_queue_create("oaoaoaoa", DISPATCH_QUEUE_SERIAL);
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
}

- (void)initUI{
    _packageNumTF.text = [NSString stringWithFormat:@"%ld",(long)_packageNumToSend];
    _packageNumTF.delegate = self;
    _packageNumTF.tag = 1000;
    _packageIntervalTF.text = [NSString stringWithFormat:@"%ld",(long)_packageSendInterval];
    _packageIntervalTF.delegate = self;
    _packageIntervalTF.tag = 1001;
    _sendButton.enabled = NO;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self.view endEditing:YES];
}

- (IBAction)sendSwitch:(UISwitch *)sender {
    if (sender.isOn) {
        _packageIndex = 0;
        _sendTimer = [NSTimer scheduledTimerWithTimeInterval:_packageSendInterval/1000.0 target:self selector:@selector(sendMessage) userInfo:nil repeats:YES];
        
    }else{
        NSLog(@"stop send");
        [_sendTimer invalidate];
        _sendTimer = nil;
    }
}


- (void)sendMessage{
    
    if (_connectedDevice && _sendCharacteristic) {
        NSLog(@"Send Message");
        uint8_t* data = malloc(sizeof(uint8_t)*_packageLength);
        memset(data, 0xFF, _packageLength);
        data[0] = (_packageIndex & 0xFF000000) >> 8*3;
        data[1] = (_packageIndex & 0x00FF0000) >> 8*2;
        data[2] = (_packageIndex & 0x0000FF00) >> 8;
        data[3] = (_packageIndex & 0x000000FF);
        
        
        NSData* dataOO = [[NSData alloc] initWithBytes:data length:_packageLength];
        
        NSString* msg = [NSString stringWithFormat:@"[%d]Send Message:%@",_packageIndex,dataOO];
        _sendStatusLabel.text = msg;
        NSLog(@"%@",msg);
        _packageIndex++;
        
        if (_packageIndex < _packageNumToSend) {
            [_connectedDevice writeValue:dataOO forCharacteristic:_sendCharacteristic type:CBCharacteristicWriteWithResponse];
        }else{
            NSLog(@"stop send");
            [_sendTimer invalidate];
            _sendTimer = nil;
            _sendButton.on = NO;
        }
        
    }
}


#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField{
    NSInteger inputNumber = [textField.text integerValue];
    if (textField.tag == 1000) {
        //package num
        if (inputNumber < 1) {
            inputNumber = 1;
            if (textField.markedTextRange == nil) {
                textField.text = [NSString stringWithFormat:@"%ld",(long)inputNumber];
            }
        }else if (inputNumber > 10000){
            inputNumber = 10000;
            if (textField.markedTextRange == nil) {
                textField.text = [NSString stringWithFormat:@"%ld",(long)inputNumber];
            }
        }
        _packageNumToSend = inputNumber;
        
    }else if(textField.tag == 1001){
        //package interval
        if (inputNumber < 1) {
            inputNumber = 1;
            if (textField.markedTextRange == nil) {
                textField.text = [NSString stringWithFormat:@"%ld",(long)inputNumber];
            }
        }else if (inputNumber > 1000){
            inputNumber = 1000;
            if (textField.markedTextRange == nil) {
                textField.text = [NSString stringWithFormat:@"%ld",(long)inputNumber];
            }
        }
        _packageSendInterval = inputNumber;
    }
}



- (void)scanBTDevice{
    /*第一个参数nil就是扫描周围所有的外设，扫描到外设后会进入
             - (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI;
     */
//    NSDictionary * dic = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],CBCentralManagerScanOptionAllowDuplicatesKey, nil];
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"636F6D2E-6A69-7561-6E2E-424C45303400"]] options:nil];
    _connectStatusLabel.text = @"Searching";
}

#pragma mark - CBCentralManagerDelegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    switch (central.state){
        case CBManagerStateUnknown:
            NSLog(@">>>CBCentralManagerStateUnknown");
            break;
        case CBManagerStateResetting:
            NSLog(@">>>CBCentralManagerStateResetting");
            break;
        case CBManagerStateUnsupported:
            NSLog(@">>>CBCentralManagerStateUnsupported");
            break;
        case CBManagerStateUnauthorized:
            NSLog(@">>>CBCentralManagerStateUnauthorized");
            break;
        case CBManagerStatePoweredOff:
            NSLog(@">>>CBCentralManagerStatePoweredOff");
            break;
        case CBManagerStatePoweredOn:
        {
            NSLog(@">>>CBCentralManagerStatePoweredOn");
            //开始扫描周围的外设
            [self scanBTDevice];
        }
            break;
        default:
            break;
    }
    
}



//扫描到设备会进入方法
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    NSArray* services = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    if ([services isKindOfClass:[NSArray class]]) {
        for (CBUUID* service in services) {
            if ([service.UUIDString isEqualToString:@"636F6D2E-6A69-7561-6E2E-424C45303400"]) {
                //connect
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"didDiscoverPeripheral %@",peripheral);
                    _connectStatusLabel.text = @"Discovered";
                    _discoveredDevice = peripheral;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [_centralManager connectPeripheral:peripheral options:nil];
                    });
                });
                
                
               
                return;
            }
        }
    }
    
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{

    NSLog(@"didConnectPeripheral %@",peripheral);
    dispatch_async(dispatch_get_main_queue(), ^{
        _connectStatusLabel.text = @"Connected";
        _connectedDevice = peripheral;
    });
    
    peripheral.delegate = self;
//    [peripheral discoverServices:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_connectedDevice) {
            [_connectedDevice discoverServices:nil];
            
        }
    });
    [central stopScan];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    
    if ((_connectedDevice && [_connectedDevice.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) || !_connectedDevice) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"connect failed");
            _connectStatusLabel.text = @"Connect Failed";
            _connectedDevice = nil;
            [self scanBTDevice];
            _sendButton.enabled = NO;
            _sendButton.on = NO;
        });

        
    }
    
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    if ((_connectedDevice && [_connectedDevice.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) || !_connectedDevice) {
        NSLog(@"dis connect");
        _connectStatusLabel.text = @"Disconnected";
        _connectedDevice = nil;
        [self scanBTDevice];
        _sendButton.enabled = NO;
        _sendButton.on = NO;
    }
}


#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if(error == nil){
        for (CBService *service in peripheral.services)
        {
            NSLog(@"service:%@",service);
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
    else{
        NSLog(@"didDiscoverServices error:%@",error);
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if(error == nil){
        for (CBCharacteristic *aChar in service.characteristics)
        {
            NSLog(@"didDiscoverCharacteristicsForService:%@",aChar);
//            [peripheral readValueForCharacteristic:aChar];
            if ([aChar.UUID.UUIDString isEqualToString:@"7365642E-6A69-7561-6E2E-424C45303400"]){
                [peripheral setNotifyValue:YES forCharacteristic:aChar];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.rcvCount = 0;
                    self.rcvArr = [NSMutableArray array];
                    self.missArr = [NSMutableArray array];
                });
                
            }else if ([aChar.UUID.UUIDString isEqualToString:@"7265632E-6A69-7561-6E2E-424C45303400"]) {
                _sendCharacteristic = aChar;
                NSLog(@"can send max: %ld WithResponse",[peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse]);
                NSLog(@"can send max: %ld WithoutResponse",[peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse]);
                _packageLength = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
                dispatch_async(dispatch_get_main_queue(), ^{
                    _sendButton.enabled = YES;
                });
                
            }
        }
    }
    else{
        NSLog(@"didDiscoverCharacteristicsForService error:%@",error);
        [_centralManager cancelPeripheralConnection:peripheral];
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{

    if(error == nil){
        

        NSLog(@"didUpdateValueForCharacteristic,%@:%@",characteristic.UUID,characteristic.value);
        NSData* dataRcv = characteristic.value;
        uint8_t* data = malloc(sizeof(uint8_t) * dataRcv.length);
        [dataRcv getBytes:data length:dataRcv.length];
        NSInteger rcvIndex = data[0] * 0x1000000 + data[1] * 0x10000 + data[2] * 0x100 + data[3];
        NSNumber* msg = @(rcvIndex);
        static NSInteger previousIndex = 0;
        previousIndex++;
        if (rcvIndex == 0) {
            self.missArr = [NSMutableArray array];
            previousIndex = 0;
        }
        if (rcvIndex != previousIndex) {
            [self.missArr addObject:@(rcvIndex)];
        }
        previousIndex = rcvIndex;
        [self.rcvArr addObject:msg];
        self.rcvCount++;
    }
    else{
        NSLog(@"didUpdateValueForCharacteristic error:%@",error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if(error==nil){
        NSLog(@"didWriteValueForCharacteristic,%@",characteristic.UUID);
    }
    else{
        NSLog(@"didWriteValueForCharacteristic error:%@",error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if(error == nil){
        
        NSLog(@"didUpdateNotificationStateForCharacteristic,%@",characteristic.UUID);
    }
    else{
        NSLog(@"didUpdateNotificationStateForCharacteristic error:%@",error);
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSLog(@"didDiscoverDescriptorsForCharacteristic,%@",characteristic.UUID);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error{
    NSLog(@"didUpdateValueForDescriptor,%@",descriptor);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error{
    NSLog(@"didWriteValueForDescriptor,%@",descriptor);
}




@end







