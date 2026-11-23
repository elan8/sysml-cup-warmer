/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * A cup warmer: a heated plate under a cup, a thermostat that warms it up and holds its temperature, and an
 * independent over-temperature cutout. The plate is a Modelica model (Warmer.mo); the controller is a SysML v2 state
 * machine. Three verification cases are run by Run42 and the verdicts appear in the report built by Doc42.
 */
package PhysicalModeling {
  private import ScalarValues::*;
  metadata def ModelicaModel {
    attribute className : String;
    attribute resourceUri : String;
  }
}

package CupWarmer {
  private import ScalarValues::*;
  private import ISQ::*;
  private import SI::*;
  private import PhysicalModeling::*;

  enum def VerificationMethodKind { test; }
  metadata def VerificationMethod { attribute kind : VerificationMethodKind; }

  port def Heat;
  part def Plate {
    @ModelicaModel { className = "Warmer.Plate"; resourceUri = "Warmer.mo"; }
    port heat : Heat;
    attribute heaterPower : PowerValue default = 40 [W];
    attribute capacity : HeatCapacityValue default = 180 [J / K];
  }
  part def Probe {
    @ModelicaModel { className = "Warmer.Probe"; resourceUri = "Warmer.mo"; }
    port heat : Heat;
    attribute offset : TemperatureDifferenceValue default = 0 [K];
  }
  part def Rig {
    part plate : Plate;
    part probe : Probe;
    connect plate.heat to probe.heat;
  }
  // The control sensor reads 30 K too low, so the thermostat lets the plate overheat.
  part def FaultySensorRig :> Rig {
    part :>> probe : Probe { attribute :>> offset = -30 [K]; }
  }

  part def Controller {
    state logic {
      attribute heat : Real = 0;
      attribute latched : Real;
      // The control sensor, and the independent over-temperature cutout's own sensor.
      attribute temperature : ThermodynamicTemperatureValue;
      attribute cutoutTemperature : ThermodynamicTemperatureValue;
      entry; then warming;
      state warming {
        entry action heatOn { assign heat := 1; assign latched := 0; }
        do action sense { while true { accept after 1 [s]; } }
      }
      state heating {
        entry action heatOn { assign heat := 1; }
        do action sense { while true { accept after 1 [s]; } }
      }
      state resting {
        entry action heatOff { assign heat := 0; }
        do action sense { while true { accept after 1 [s]; } }
      }
      state tripped { entry action latchOff { assign heat := 0; assign latched := 1; } }
      // Thermostat: warm up to 62 C, then hold between 60 and 65 C.
      transition reached first warming accept when temperature >= 335.15 [K] then resting;
      transition cooled first resting accept when temperature <= 333.15 [K] then heating;
      transition warm first heating accept when temperature >= 338.15 [K] then resting;
      // Cutout: at 85 C on its own sensor, switch off and stay off.
      transition cutoutWarming first warming accept when cutoutTemperature >= 358.15 [K] then tripped;
      transition cutoutHeating first heating accept when cutoutTemperature >= 358.15 [K] then tripped;
      transition cutoutResting first resting accept when cutoutTemperature >= 358.15 [K] then tripped;
    }
  }

  requirement <'CW-001'> warmsUpInTime {
    doc /* From 20 degC, the plate under a cup reaches 62 degC within 300 s. */
  }
  requirement <'CW-002'> holdsTemperature {
    doc /* After warming up, the plate holds the cup between 58 and 67 degC. */
  }
  requirement <'CW-003'> cutsOutOnSensorFault {
    doc /* If the control sensor reads 30 K too low, an independent cutout switches the heater off and keeps it off before the plate exceeds 90 degC. */
  }

  verification warmsUp {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject controller : Controller;
    objective { verify warmsUpInTime; }
    action stimulus { accept after 300 [s]; }
    assert constraint reachedTemperature { controller.logic.temperature >= 335.15 [K] }
  }

  verification holds {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject controller : Controller;
    objective { verify holdsTemperature; }
    action stimulus { accept after 900 [s]; }
    assert constraint withinBand {
      controller.logic.temperature >= 331.15 [K] and controller.logic.temperature <= 340.15 [K]
    }
  }

  verification sensorFault {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject controller : Controller;
    objective { verify cutsOutOnSensorFault; }
    action stimulus { accept after 480 [s]; }
    assert constraint cutOutAndOff {
      controller.logic.latched == 1 and controller.logic.heat == 0
        and controller.logic.cutoutTemperature <= 363.15 [K]
    }
  }
}
