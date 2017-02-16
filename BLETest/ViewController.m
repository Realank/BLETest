//
//  ViewController.m
//  BLETest
//
//  Created by Realank on 2017/1/19.
//  Copyright © 2017年 iMooc. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *connectStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *sendStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *receiveStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *missStatusLabel;
@property (weak, nonatomic) IBOutlet UITextField *packageNumTF;
@property (weak, nonatomic) IBOutlet UITextField *packageIntervalTF;
@property (weak, nonatomic) IBOutlet UITextView *logTextView;

@property (nonatomic, strong) CBCentralManager* centralManager;
@property (nonatomic, strong) NSMutableArray* missedPackageArray;
@property (nonatomic, strong) CBPeripheral* connectedDevice;
@property (nonatomic, assign) NSInteger packageNumToSend;
@property (nonatomic, assign) NSInteger packageSendInterval;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _packageNumToSend = 10;
    _packageSendInterval = 1000;//ms
    [self initUI];
    [self initBTManager];
}

- (void)initBTManager{
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)initUI{
    _packageNumTF.text = [NSString stringWithFormat:@"%ld",(long)_packageNumToSend];
    _packageNumTF.delegate = self;
    _packageNumTF.tag = 1000;
    _packageIntervalTF.text = [NSString stringWithFormat:@"%ld",(long)_packageSendInterval];
    _packageIntervalTF.delegate = self;
    _packageIntervalTF.tag = 1001;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self.view endEditing:YES];
}

- (IBAction)beginConnect:(id)sender {
}

- (IBAction)sendSwitch:(UISwitch *)sender {
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

#pragma mark - CBCentralManagerDelegate

- (void)scanBTDevice{
    /*第一个参数nil就是扫描周围所有的外设，扫描到外设后会进入
             - (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI;
     */
    NSDictionary * dic = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:false],CBCentralManagerScanOptionAllowDuplicatesKey, nil];
    [_centralManager scanForPeripheralsWithServices:nil options:dic];
    _connectStatusLabel.text = @"Searching";
}

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
    
    NSLog(@"扫描到设备:%@",peripheral);
    
}

@end
