module.exports = ({GET, resources}) => {
  GET('/', { to: 'index#index' })
  resources('todos', { only: ['create', 'destroy'] })
}
