//
// Created by haridev on 3/28/23.
//

#include <dftracer/core/dftracer_main.h>
#include <dftracer/df_logger.h>
#include <dftracer/dftracer_preload.h>
#include <dftracer/utils/configuration_manager.h>

#include <algorithm>

namespace dftracer {
bool init = false;
}

bool is_init() { return dftracer::init; }

void set_init(bool _init) { dftracer::init = _init; }

void dftracer_init(void) {
  auto conf =
      dftracer::Singleton<dftracer::ConfigurationManager>::get_instance();
  if (conf != nullptr) {
    DFTRACER_LOG_DEBUG("dftracer_init", "");
    if (conf->init_type == PROFILER_INIT_LD_PRELOAD) {
      dftracer::Singleton<dftracer::DFTracerCore>::get_instance(
          ProfilerStage::PROFILER_INIT, ProfileType::PROFILER_PRELOAD);
    }
  }
}

void dftracer_fini(void) {
  auto conf =
      dftracer::Singleton<dftracer::ConfigurationManager>::get_instance();
  DFTRACER_LOG_DEBUG("dftracer_fini", "");
  auto dftracer_inst =
      dftracer::Singleton<dftracer::DFTracerCore>::get_instance(
          ProfilerStage::PROFILER_FINI, ProfileType::PROFILER_PRELOAD);
  if (dftracer_inst != nullptr) {
    dftracer_inst->finalize();
  }
}