module Netpar
  # Odmowa weryfikacji: świadectwo wydane przed dniem, od którego jego rodzaj podlega weryfikacji internetowej
  # (NETPAR 403, reason: issued_before_limit, verifiable_from – ustawiane w NETPAR przy rodzaju świadectwa).
  IssuedBeforeLimit = Data.define(:verifiable_from)
end
