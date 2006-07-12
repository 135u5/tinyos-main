/* $Id: RandRWC.nc,v 1.2 2006-07-12 16:59:32 scipio Exp $
 * Copyright (c) 2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/**
 * Log storage test application. Does a pattern of random reads and
 * writes, based on mote id. See README.txt for more details.
 *
 * @author David Gay
 */
/*
  address & 3:
  1: erase, write
  2: read
  3: write some more
*/
module RandRWC {
  uses {
    interface Boot;
    interface Leds;
    interface LogRead;
    interface LogWrite;
    interface AMSend;
    interface SplitControl as SerialControl;
  }
}
implementation {
  enum {
    SIZE = 1024L * 256,
    NWRITES = SIZE / 512,
  };

  uint16_t shiftReg;
  uint16_t initSeed;
  uint16_t mask;

  void done();

  /* Return the next 16 bit random number */
  uint16_t rand() {
    bool endbit;
    uint16_t tmpShiftReg;

    tmpShiftReg = shiftReg;
    endbit = ((tmpShiftReg & 0x8000) != 0);
    tmpShiftReg <<= 1;
    if (endbit) 
      tmpShiftReg ^= 0x100b;
    tmpShiftReg++;
    shiftReg = tmpShiftReg;
    tmpShiftReg = tmpShiftReg ^ mask;

    return tmpShiftReg;
  }

  void resetSeed() {
    shiftReg = 119 * 119 * ((TOS_NODE_ID % 100) + 1);
    initSeed = shiftReg;
    mask = 137 * 29 * ((TOS_NODE_ID % 100) + 1);
  }
  
  uint8_t data[512], rdata[512];
  int count, testCount;
  uint32_t len;
  uint16_t offset;
  message_t reportmsg;

  void report(error_t e) {
    uint8_t *msg = call AMSend.getPayload(&reportmsg);

    msg[0] = e;
    if (call AMSend.send(AM_BROADCAST_ADDR, &reportmsg, 1) != SUCCESS)
      call Leds.led0On();
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if (error != SUCCESS)
      call Leds.led0On();
  }

  void fail(error_t e) {
    call Leds.led0On();
    report(e);
  }

  void success() {
    call Leds.led1On();
    report(0x80);
  }

  bool scheck(error_t r) __attribute__((noinline)) {
    if (r != SUCCESS)
      fail(r);
    return r == SUCCESS;
  }

  bool bcheck(bool b) {
    if (!b)
      fail(FAIL);
    return b;
  }

  void setParameters() {
    len = rand() >> 8;
    offset = rand() >> 9;
    if ( len > 254 )
      len = 254;
    if (offset + len > sizeof data)
      offset = sizeof data - len;
  }

  void nextRead() {
    if (count == NWRITES)
      count = 0;
    if (count++ == 0)
      resetSeed();
    setParameters();
    scheck(call LogRead.read(rdata, len));
  }

  event void LogRead.readDone(void* buf, storage_len_t rlen, error_t result) __attribute__((noinline)) {
    if (len != 0 && rlen == 0)
      done();
    else if (scheck(result) && bcheck(rlen == len && buf == rdata && memcmp(data + offset, rdata, rlen) == 0))
      nextRead();
  }

  event void LogRead.seekDone(error_t error) {
  }

  void nextWrite() {
    if (count++ == NWRITES)
      scheck(call LogWrite.sync());
    else
      {
	setParameters();
	scheck(call LogWrite.append(data + offset, len));
      }
  }

  event void LogWrite.appendDone(void *buf, storage_len_t y, error_t result) {
    if (scheck(result))
      nextWrite();
  }

  event void LogWrite.eraseDone(error_t result) {
    if (scheck(result))
      done();
  }

  event void LogWrite.syncDone(error_t result) {
    if (scheck(result))
      done();
  }

  event void Boot.booted() {
    int i;

    resetSeed();
    for (i = 0; i < sizeof data; i++)
      data[i++] = rand() >> 8;

    call SerialControl.start();
  }

  event void SerialControl.stopDone(error_t e) { }

  event void SerialControl.startDone(error_t e) {
    if (e != SUCCESS)
      {
	call Leds.led0On();
	return;
      }

    testCount = 0;
    done();
  }

  enum { A_ERASE = 1, A_READ, A_WRITE };

  void doAction(int act) {
    switch (act)
      {
      case A_ERASE:
	scheck(call LogWrite.erase());
	break;
      case A_WRITE:
	resetSeed();
	count = 0;
	nextWrite();
	break;
      case A_READ:
	resetSeed();
	count = 0;
	nextRead();
	break;
      }
  }

  const uint8_t actions[] = {
    A_ERASE, 
    A_READ,
    A_WRITE,
    A_READ,
    A_WRITE,
    A_WRITE,
    A_WRITE,
    A_READ,
    A_ERASE,
    A_READ,
    A_WRITE,
    A_WRITE
  };

  void done() {
    uint8_t act = TOS_NODE_ID / 100;

    call Leds.led2Toggle();

    switch (act)
      {
      case 0:
	if (testCount < sizeof actions)
	  doAction(actions[testCount]);
	else
	  success();
	break;

      case A_ERASE: case A_READ: case A_WRITE:
	if (testCount)
	  success();
	else
	  doAction(act);
	break;

      default:
	fail(FAIL);
	break;
      }
    testCount++;
  }
}
