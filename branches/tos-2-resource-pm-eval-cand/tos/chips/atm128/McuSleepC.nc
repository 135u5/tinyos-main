/// $Id: McuSleepC.nc,v 1.1.2.4.6.2 2006-05-15 19:08:27 klueska Exp $

/*
 * "Copyright (c) 2005 Stanford University. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the following two paragraphs and the author appear in all
 * copies of this software.
 * 
 * IN NO EVENT SHALL STANFORD UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
 * ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN
 * IF STANFORD UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 * 
 * STANFORD UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
 * PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND STANFORD UNIVERSITY
 * HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
 * ENHANCEMENTS, OR MODIFICATIONS."
 */

/**
 * Implementation of TEP 112 (Microcontroller Power Management) for
 * the Atmega128. Power state calculation code copied from Rob
 * Szewczyk's 1.x code in HPLPowerManagementM.nc.
 *
 * <pre>
 *  $Id: McuSleepC.nc,v 1.1.2.4.6.2 2006-05-15 19:08:27 klueska Exp $
 * </pre>
 *
 * @author Philip Levis
 * @author Robert Szewczyk
 * @date   October 26, 2005
 */

module McuSleepC {
  provides {
    interface McuSleep;
    interface McuPowerState;
  }
  uses {
    interface McuPowerOverride;
  }
}
implementation {
  /* There is no dirty bit management because the sleep mode depends on
     the amount of time remaining in timer0. */

  /* Note that the power values are maintained in an order
   * based on their active components, NOT on their values.
   * Look at atm128hardware.h and page 42 of the ATmeg128
   * manual (figure 17).*/
  const_uint8_t atm128PowerBits[ATM128_POWER_DOWN + 1] = {
    0,
    (1 << SM0),
    (1 << SM2) | (1 << SM1) | (1 << SM0),
    (1 << SM1) | (1 << SM0),
    (1 << SM2) | (1 << SM1),
    (1 << SM1)};
    
  mcu_power_t getPowerState() {
    uint8_t diff;
    // Note: we go to sleep even if timer 1, 2, or 3's overflow interrupt
    // is enabled - this allows using these timers as TinyOS "Alarm"s
    // while still having power management.

    // Are external timers running?  
    if (TIMSK & ~(1 << OCIE0 | 1 << TOIE0 | 1 << TOIE1 | 1 << TOIE2) ||
	ETIMSK & ~(1 << TOIE3)) {
      return ATM128_POWER_IDLE;
    }
    // SPI (Radio stack on mica/micaZ
    else if (bit_is_set(SPCR, SPIE)) { 
      return ATM128_POWER_IDLE;
    }
    // UARTs are active
    else if (UCSR0B & (1 << TXCIE | 1 << RXCIE)) { // UART
      return ATM128_POWER_IDLE;
    }
    else if (UCSR1B & (1 << TXCIE | 1 << RXCIE)) { // UART
      return ATM128_POWER_IDLE;
    }
    // ADC is enabled
    else if (bit_is_set(ADCSR, ADEN)) { 
      return ATM128_POWER_ADC_NR;
    }
    // How soon for the timer to go off?
    else if (TIMSK & (1 << OCIE0 | 1 << TOIE0)) {
      // force waiting for timer0 update (overflow glitches otherwise)
      TCCR0 = TCCR0;
      while (ASSR & (1 << TCN0UB | 1 << OCR0UB | 1 << TCR0UB))
	;
      diff = OCR0 - TCNT0;
      if (diff < 16 || TCNT0 > 240) 
	return ATM128_POWER_EXT_STANDBY;
      return ATM128_POWER_SAVE;
    }
    else {
      return ATM128_POWER_DOWN;
    }
  }
  
  async command void McuSleep.sleep() {
    uint8_t powerState;

    powerState = mcombine(getPowerState(), call McuPowerOverride.lowestState());
    MCUCR =
      (MCUCR & 0xe3) | 1 << SE | read_uint8_t(&atm128PowerBits[powerState]);

    sei();
    asm volatile ("sleep");
    cli();
  }

  async command void McuPowerState.update() {
  }

  default async command mcu_power_t McuPowerOverride.lowestState() {
    return ATM128_POWER_DOWN;
  }
}
