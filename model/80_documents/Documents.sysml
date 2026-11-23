/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * The verification report of the cup warmer. The requirements are read from the model and the verdicts from the file
 * that Run42 wrote (build/verdicts.json, see scripts/verify.sh), so the report cannot drift from either.
 */
package CupWarmerDocuments {
  private import Elan8::Documents::*;
  private import StandardViewDefinitions::*;

  view report {
    @Document {
      title = "Cup Warmer";
      subtitle = "Verification Report";
      organization = "Elan8";
      number = "CW-VR-001";
      revision = "A";
      status = "Example";
      template = "template";
    }

    view purpose {
      @Section { title = "Purpose"; }
      doc /* This report shows what was verified about the cup warmer design and what the simulation found. Every
             requirement comes from the SysML v2 model, and every verdict and number from a Run42 run of the case that
             verifies it. The report is rebuilt on every change. */
    }

    view results {
      @Section { title = "Requirements and verdicts"; }
      @Table {
        columns = "ID = id, Requirement = text, Verified by = verified-by, Verdict = verified-by / verdict, Detail = verified-by / verdict-detail";
        kind = "requirement";
        verdicts = "../../build/verdicts.json";
        caption = "The requirements of the cup warmer and the verdict of the case that verifies each.";
      }
      expose CupWarmer::*;
    }

    view design {
      @Section { title = "Design parameters"; }
      @Prose { file = "../../build/parameters.md"; }
    }

    view measurements {
      @Section { title = "Results"; }
      doc /* The traces below are what Run42 recorded when it ran the cases: the temperature of the plate once per second.
             The key figures are measured on them, so the report shows how much margin each requirement has, not only
             whether it holds. */
      @Prose { file = "../../build/results.md"; }

      view warmingUp {
        @Section { title = "Warming up (CW-001)"; }
        @Figure { file = "../../build/figures/warms-up.svg"; caption = "The plate warms up with the heater on until it reaches 62 degC, then the thermostat takes over. The dashed lines are the target and the time limit."; }
      }
      view holding {
        @Section { title = "Holding the temperature (CW-002)"; }
        @Figure { file = "../../build/figures/holds-temperature.svg"; caption = "The thermostat switches the heater between 60 and 65 degC. The shaded band is the requirement."; }
      }
      view sensorFault {
        @Section { title = "Sensor fault (CW-003)"; }
        @Figure { file = "../../build/figures/sensor-fault.svg"; caption = "The control sensor reads 30 K too low, so the thermostat keeps heating. The independent cutout switches the heater off at 85 degC."; }
      }
    }

    view alternative {
      @Section { title = "Design alternative"; }
      doc /* A cheaper heater of 25 W was evaluated against the same warm-up requirement. It is shown here because it
             fails: the comparison is the reason the chosen design has a 40 W heater. */
      @Table {
        columns = "ID = id, Requirement = text, Verified by = verified-by, Verdict = verified-by / verdict, Detail = verified-by / verdict-detail";
        kind = "requirement";
        verdicts = "../../build/alternative-verdicts.json";
        caption = "The warm-up requirement of the alternative and the verdict of its case.";
      }
      expose CupWarmer::Alternatives::*;
      @Prose { file = "../../build/alternative.md"; }
      @Figure { file = "../../build/figures/design-comparison.svg"; caption = "The same warm-up with the chosen 40 W heater and the rejected 25 W heater."; }
    }

    view method {
      @Section { title = "Method"; }
      doc /* The plate is a Modelica model: heater power, heat capacity of the plate and cup, and heat loss to the air.
             The controller is a SysML v2 state machine that senses the temperature once a second. A case runs the
             controller against the plate and checks an assertion at the end of its stimulus. The sensor-fault case
             uses a plate whose control sensor reads 30 K too low. The figures are computed from the recorded traces by
             `scripts/report_data.py`. */
    }

    view limits {
      @Section { title = "Limits of this evidence"; }
      doc /* The plate model is a first estimate with assumed parameters, not measured values. The verdicts hold for this
             model and these parameters only. They are simulation results, not test results of a real appliance, and they
             do not show compliance with any standard. */
    }
  }
}
