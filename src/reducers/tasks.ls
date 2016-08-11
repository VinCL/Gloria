'use strict'

require! 'node-uuid': uuid
require! '../actions/types.ls': types

const actions-map =
  (types.add-task): (state, { name, code, trigger-interval, need-interaction, trigger-count, push-count, is-enable, origin }) ->
    [...state, {
      id: uuid.v4!
      name
      code
      trigger-interval
      need-interaction
      trigger-count
      push-count
      is-enable
      origin
    }]

  (types.edit-task): (state, { id, name, code }) ->
    state.map (x) ->
      return x if x.id isnt id
      {
        ...x
        name: name
        code: code
      }

  (types.remove-task): (state, { id }) ->
    state.filter (x) -> x.id isnt id

  (types.remove-task-by-origin): (state, { origin }) ->
    state.filter (x) -> x.origin isnt origin

  (types.set-trigger-interval): (state, { id, trigger-interval }) ->
    state.map (x) ->
      return x if x.id isnt id
      {
        ...x
        trigger-interval
      }

  (types.set-need-interaction): (state, { id, need-interaction }) ->
    state.map (x) ->
      return x if x.id isnt id
      {
        ...x
        need-interaction
      }

  (types.set-is-enable): (state, { id, is-enable }) ->
    state.map (x) ->
      return x if x.id isnt id
      {
        ...x
        is-enable
      }

  (types.increase-trigger-count): (state, { id }) ->
    state.map (x) ->
      return x if x.id isnt id
      {
        ...x
        trigger-count: x.trigger-count + 1
      }

  (types.increase-push-count): (state, { id }) ->
    state.map (x) ->
      return x if x.id isnt id
      {
        ...x
        push-count: x.push-count + 1
      }

  (types.clear-all-tasks): -> []

module.exports = (state = [], action) ->
  const reduce-fn = actions-map[action.type]
  if reduce-fn then reduce-fn state, action else state
