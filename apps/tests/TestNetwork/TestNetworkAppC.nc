/**
 * TestNetworkC exercises the basic networking layers, collection and
 * dissemination. The application samples DemoSensorC at a basic rate
 * and sends packets up a collection tree. The rate is configurable
 * through dissemination.
 *
 * See TEP118: Dissemination and TEP 119: Collection for details.
 * 
 * @author Philip Levis
 * @version $Revision: 1.1.2.8 $ $Date: 2006-06-14 20:51:17 $
 */
#include "TestNetwork.h"

configuration TestNetworkAppC {}
implementation {
  components TestNetworkC, MainC, LedsC, ActiveMessageC;
  components new DisseminatorC(uint16_t, SAMPLE_RATE_KEY) as Object16C;
  components new CollectionSenderC(CL_TEST);
  components TreeCollectionC as Collector;
  components new TimerMilliC();
  components new DemoSensorC();
  components new SerialAMSenderC(CL_TEST);
  components SerialActiveMessageC;
  components new SerialAMSenderC(0x09) as UARTSender;
  components UARTDebugSenderP as DebugSender;

  TestNetworkC.Boot -> MainC;
  TestNetworkC.RadioControl -> ActiveMessageC;
  TestNetworkC.SerialControl -> SerialActiveMessageC;
  TestNetworkC.RoutingControl -> Collector;
  TestNetworkC.Leds -> LedsC;
  TestNetworkC.Timer -> TimerMilliC;
  TestNetworkC.DisseminationPeriod -> Object16C;
  TestNetworkC.Send -> CollectionSenderC;
  TestNetworkC.ReadSensor -> DemoSensorC;
  TestNetworkC.RootControl -> Collector;
  TestNetworkC.Receive -> Collector.Receive[CL_TEST];
  TestNetworkC.UARTSend -> SerialAMSenderC.AMSend;
  TestNetworkC.CollectionPacket -> Collector;
  TestNetworkC.TreeRoutingInspect -> Collector;

  DebugSender.Boot -> MainC;
  DebugSender.UARTSend -> UARTSender;
  Collector.CollectionDebug -> DebugSender;
}
