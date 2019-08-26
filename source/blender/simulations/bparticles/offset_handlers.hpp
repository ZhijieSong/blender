#pragma once

#include "step_description.hpp"
#include "particle_function.hpp"

namespace BParticles {

class CreateTrailHandler : public OffsetHandler {
 private:
  Vector<std::string> m_types_to_emit;
  std::unique_ptr<ParticleFunction> m_compute_inputs;
  std::unique_ptr<Action> m_on_birth_action;

 public:
  CreateTrailHandler(Vector<std::string> types_to_emit,
                     std::unique_ptr<ParticleFunction> compute_inputs,
                     std::unique_ptr<Action> on_birth_action)
      : m_types_to_emit(std::move(types_to_emit)),
        m_compute_inputs(std::move(compute_inputs)),
        m_on_birth_action(std::move(on_birth_action))
  {
  }

  void execute(OffsetHandlerInterface &interface) override;
};

}  // namespace BParticles