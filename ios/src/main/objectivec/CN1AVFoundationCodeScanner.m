#import "com_codename1_ext_codescan_CodeScanner.h"
#import "CN1AVFoundationCodeScanner.h"
#import "CodenameOne_GLViewController.h"

@implementation CN1AVFoundationCodeScanner

- (instancetype)initWithMetadataObjectTypes:(NSArray *)metadataObjectTypes {
    self = [super init];
    if (self) {
        self.metadataObjectTypes = metadataObjectTypes;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Additional setup if needed
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self scanBarCode];
}

- (void)scanBarCode {
    // Check camera permission status first
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted) {
        // Camera permission denied
        com_codename1_ext_codescan_CodeScanner_scanErrorCallback___int_java_lang_String(CN1_THREAD_GET_STATE_PASS_ARG -2, fromNSString(CN1_THREAD_GET_STATE_PASS_ARG @"Camera permission denied"));
        [self dismissModalViewControllerAnimated:YES];
        return;
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // Request permission
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                [self performScanBarCode];
            } else {
                com_codename1_ext_codescan_CodeScanner_scanErrorCallback___int_java_lang_String(CN1_THREAD_GET_STATE_PASS_ARG -2, fromNSString(CN1_THREAD_GET_STATE_PASS_ARG @"Camera permission denied"));
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self dismissModalViewControllerAnimated:YES];
                });
            }
        }];
        return;
    }
    
    // Permission already granted, proceed with scanning
    [self performScanBarCode];
}

- (void)performScanBarCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        POOL_BEGIN();

        self.session = [[AVCaptureSession alloc] init];
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!input) {
            NSLog(@"Error: %@", error);
            // Call error callback and return
            com_codename1_ext_codescan_CodeScanner_scanErrorCallback___int_java_lang_String(CN1_THREAD_GET_STATE_PASS_ARG -1, fromNSString(CN1_THREAD_GET_STATE_PASS_ARG [error localizedDescription]));
            [self dismissModalViewControllerAnimated:YES];
            POOL_END();
            return;
        }
        [self.session addInput:input];

        AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
        [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        [self.session addOutput:output];

        // Specify the types of metadata objects to recognize
        if (self.metadataObjectTypes && self.metadataObjectTypes.count > 0) {
            output.metadataObjectTypes = self.metadataObjectTypes;
        } else {
            output.metadataObjectTypes = output.availableMetadataObjectTypes;
        }

        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.previewLayer.frame = self.view.layer.bounds;
        [self.view.layer addSublayer:self.previewLayer];

        // Add visible Cancel button
        [self addCancelButton];

        [self.session startRunning];
        POOL_END();
    });
}

- (void)addCancelButton {
    // Create a Cancel button in the top-right corner
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5]; // Semi-transparent background
    cancelButton.layer.cornerRadius = 8;
    cancelButton.frame = CGRectMake(self.view.frame.size.width - 100, 50, 80, 40);
    [cancelButton addTarget:self action:@selector(cancelScanning) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancelButton];
}

- (void)cancelScanning {
    [self cleanupScanning];
    com_codename1_ext_codescan_CodeScanner_scanCanceledCallback__(CN1_THREAD_GET_STATE_PASS_SINGLE_ARG);
}

-(void)cleanupScanning {
    [self.session stopRunning];
    [self.previewLayer removeFromSuperlayer];
    // Remove the cancel button
    for (UIView *subview in self.view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            [subview removeFromSuperview];
        }
    }
    [self dismissModalViewControllerAnimated: YES];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    for (AVMetadataObject *metadataObject in metadataObjects) {
        if (![metadataObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            continue;
        }
        if (self.metadataObjectTypes == nil || self.metadataObjectTypes.count == 0 || [self.metadataObjectTypes containsObject:metadataObject.type]) {
            AVMetadataMachineReadableCodeObject *readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
            NSString *scannedResult = readableObject.stringValue;
            NSString *codeType = readableObject.type;
            // Handle the scanned result
            NSLog(@"Scanned code: %@", scannedResult);
            [self.session stopRunning]; // Stop the session once we get a result
            [self.previewLayer removeFromSuperlayer];
            [self cleanupScanning]; // Clean up gesture recognizers and dismiss view controller
            com_codename1_ext_codescan_CodeScanner_scanCompletedCallback___java_lang_String_java_lang_String_byte_1ARRAY(
                CN1_THREAD_GET_STATE_PASS_ARG
                fromNSString(
                    CN1_THREAD_GET_STATE_PASS_ARG
                    scannedResult
                ),
                fromNSString(
                    CN1_THREAD_GET_STATE_PASS_ARG
                    codeType
                ),
                JAVA_NULL
            );
            break;
        }
    }
}

@end
