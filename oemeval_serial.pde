import processing.serial.*;
import oscP5.*;
import netP5.*;

Serial oemSerial;
OscP5 oscP5;
NetAddress myRemoteLocation;


// Settings
int oscPort = 57120;

// Frames
static int frameSize = 5;
int[] recievedBytes = new int[frameSize];
byte ndx = 0;

// Packets
boolean packetStart = false;
int packetFrame = 0;
int packetSize = 25;
boolean newData = false;
boolean recvInProgress = false;

final int F2_FRAME_START_INDEX = 0;
final int F2_FRAME_STATUS_INDEX = 1;
final int F2_FRAME_PLETH_INDEX = 2;
final int F2_FRAME_CHANGING_INDEX = 3;
final int F2_FRAME_CHECKSUM_INDEX = 4;

// Data Format 2 Status
final int F2_STATUS_SYNC = 0;
final int F2_STATUS_GPRF = 1;
final int F2_STATUS_RPRF = 2;
final int F2_STATUS_SNSA = 3;
final int F2_STATUS_OOT  = 4;
final int F2_STATUS_ARTF = 5;
final int F2_STATUS_SNSD = 6;
final int F2_STATUS_FLAG = 7;

// Data Format 2 Frame Index Changing Value\
final int F2_CHNG_HR_MSB = 1;
final int F2_CHNG_HR_LSB = 2;
final int F2_CHNG_SPO2 = 3;
final int F2_CHNG_REV = 4;

final int F2_CHNG_SPO2D = 9;
final int F2_CHNG_SPO2_FAST = 10;
final int F2_CHNG_SPO2_BB = 11;

final int F2_CHNG_E_HR_MSB = 14;
final int F2_CHNG_E_HR_LSB = 15;
final int F2_CHNG_E_SPO2 = 16;
final int F2_CHNG_E_SPO2_D = 17;

final int F2_CHNG_HR_D_MSB = 20;
final int F2_CHNG_HR_D_LSB = 21;
final int F2_CHNG_E_HR_D_MSB = 22;
final int F2_CHNG_E_HR_D_LSB = 23;

final boolean DEBUG = true;

void setup () {
  size(800, 600);        // window size
  
  oscP5 = new OscP5(this, 12000);   //listening
  myRemoteLocation = new NetAddress("127.0.0.1", oscPort);  //  speak to
 
  oemSerial = new Serial(this, "/dev/cu.usbserial-A1043Y87", 9600);

}

void draw () {
  // everything happens in the serialEvent()
}

void serialEvent (Serial myPort) {
   recvWithStartEndInt(myPort);       // ...
   processNewFrame();
}

String packetColumn (int packetByte) {
  if(packetByte == 2){
    return "Status";
  }
  if(packetByte == 3){
    return "Pleth";
  }
  if(packetByte == 4){
    return "Different";
  }
  if(packetByte == 5){
    return "Checksum";
  }
  return "?!?";
}


void recvWithStartEndInt(Serial port) {
  
  int startInt = 1;          // 128 is integer equivalent of 1000 0000 <- start bit
  int endInt = 64;             // 64 is integer equivalent of 0100 0000 <- stop bit
  int ri;                      //
  
  if (port.available() > 0 && newData == false) {
     
   ri = port.read();

   if (recvInProgress == true) {
     if (ri != endInt) {
       ndx++;
       recievedBytes[ndx] = ri;
       
       if (ndx >= (frameSize - 1)) {
         if( ndx == frameSize - 1) {
           if( (byte)ri == ((byte)recievedBytes[0] + (byte)recievedBytes[1] + (byte)recievedBytes[2] + (byte)recievedBytes[3])) {
             recvInProgress = false;
             ndx = 0;
             newData = true;
           }
         }
         ndx = 0;
         recvInProgress = false;
       }
     }
    }

    else if (ri == startInt) {
      recievedBytes[ndx] = ri;
      recvInProgress = true;
    }
  }
  
}


void processNewFrame() {
  
  if (newData == true) {
    
    checkForPacketStart();
    packetFrame++;
    
    if(packetFrame > packetSize) {
      packetStart = false;
    }
    
    // get the byte:
    for(int i = 0; i < frameSize; i++) {
      if(i == 1)
      {
         if(DEBUG) { println(""); }
      }
      else
      {
         if(DEBUG) {
           printF2Packet(packetFrame, i, (byte)recievedBytes[i]);   
         }
         if(packetStart) {
           // TODO: send OSC
         }
         else {
           println("No Frame");
         }
         
      }
    }
    newData = false;
  }
}

void printF2Packet(int packetIndex, int frameIndex, byte value) {
  if(frameIndex == F2_FRAME_START_INDEX) {
    println("");
  }
  else if(frameIndex == F2_FRAME_STATUS_INDEX) {
    printF2Status(value);
  }
  else if(frameIndex == F2_FRAME_PLETH_INDEX) {
    println("PLETH\t " + value);
    OscMessage newMessage = new OscMessage("/hr/pleth");  
    newMessage.add(value); 
    oscP5.send(newMessage, myRemoteLocation);
  }
  else if(frameIndex == F2_FRAME_CHANGING_INDEX) {
    printF2Changing(packetIndex, value);
  }
}

void printF2Status(byte statusByte) {
  boolean sync = isSet(statusByte, F2_STATUS_SYNC);
  boolean gprf = isSet(statusByte, F2_STATUS_GPRF);
  boolean rprf = isSet(statusByte, F2_STATUS_RPRF);
  boolean snsa = isSet(statusByte, F2_STATUS_SNSA);
  boolean oot = isSet(statusByte, F2_STATUS_OOT);
  boolean artf = isSet(statusByte, F2_STATUS_ARTF);
  boolean snsd = isSet(statusByte, F2_STATUS_SNSD);
  
  println("Sync\t " + sync);
  println("GPRF\t " + gprf);
  println("RPRF\t " + rprf);
  println("SNSA\t " + snsa);
  println("OOT\t " + oot);
  println("ARTF\t " + artf);
  println("SNSD\t " + snsd);
}

void printF2Changing(int packetIndex, byte value) {
  switch (packetIndex) {
    case F2_CHNG_HR_MSB:
      println("HR_MSB\t" + value);
      break;
    case F2_CHNG_HR_LSB:
      println("HR_LSB\t" + value);
      break;
    case F2_CHNG_SPO2:
      println("SPO2\t" + value);
      break;
    case F2_CHNG_REV:
      println("REV\t" + value);
      break;
    case F2_CHNG_SPO2D:
      println("SPO2D\t" + value);
      break;
    case F2_CHNG_SPO2_FAST:
      println("SPO2_FAST\t" + value);
      break;
    case F2_CHNG_SPO2_BB:
      println("SPO2_BB\t" + value);
      break;
    case F2_CHNG_E_HR_MSB:
      println("E_HR_MSB\t" + value);
      break;
    case F2_CHNG_E_HR_LSB:
      println("E_HR_LSB\t" + value);
      break;
    case F2_CHNG_E_SPO2:
      println("E_SPO2\t" + value);
      break;
    case F2_CHNG_E_SPO2_D:
      println("E_SPO2_D\t" + value);
      break;
    case F2_CHNG_HR_D_MSB:
      println("HR_D_MSB\t" + value);
      break;
    case F2_CHNG_HR_D_LSB:
      println("HR_D_LSB\t" + value);
      break;
    case F2_CHNG_E_HR_D_MSB:
      println("E_HR_D_MSB\t" + value);
      break;
    case F2_CHNG_E_HR_D_LSB:
      println("E_HR_D_LSB\t" + value);
      break;
  }
}

void checkForPacketStart() {
  if(isSet((byte)recievedBytes[F2_FRAME_STATUS_INDEX], F2_STATUS_SYNC)) {
    packetStart = true;
    packetFrame = 0;
  }
}

static final boolean isSet(byte b, int pos) {
  return (pos|7) == 7 & (b>>>pos & 1) == 1;
}