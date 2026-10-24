# Naming

- Names should describe *what*, not *how*.
- Prefer clear, full words over abbreviations.
- Boolean names should read as predicates: `is_valid`, `has_error`, `can_retry`.
- Avoid filler words: `data`, `info`, `manager`, `handler`, `util` are smells as
  a generic suffix that names a module or class by its kind (`user_data`,
  `event_handler_manager`, `string_utils`). Where the word is the domain's precise
  term, it's the right name: a function passed as `on_input` _is_ a handler, and
  calling it a "behavior" to dodge this rule tells the reader less.
