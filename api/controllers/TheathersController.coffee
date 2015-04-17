tmdb = require('moviedb')(sails.config.tmdbApiKey)
showtimes = require('showtimes')
cache = require('lru-cache')()

class TheatersController
  index: (req, res)->
    @location = req.query.location
    @getShowtimes (data)->
      res.json data

  getShowtimes: (callback)->
    if cache.has @showtimesCacheKey()
      callback cache.get(@showtimesCacheKey())
    else
      sails.log.debug 'fetchShowtimes:start', { location: @location, date: '' }
      showtimes(@location).getTheaters (err, theaters)=>
        if err
          sails.log.warn err
        else
          sails.log.debug 'fetchShowtimes:finish'
        @removeInvalidTheaters theaters
        movies = @fetchMoviesFromTheaters theaters
        @fetchMoviesInfo movies, (data)=>
          data = { theaters: theaters, movies: data }
          cache.set @showtimesCacheKey(), data
          callback data

  showtimesCacheKey: ->
    "showtimes #{@location}"

  removeInvalidTheaters: (theaters)->
    sails.log.debug 'removeInvalidTheaters:start'
    _.remove theaters, (theater)->
      theater.id is ''
    sails.log.debug 'removeInvalidTheaters:finish'

  fetchMoviesFromTheaters: (theaters)->
    sails.log.debug 'fetchMoviesFromTheaters:start'
    movies = _.flatten( _.pluck(_.cloneDeep(theaters), 'movies') )
    movies = _.uniq(movies, 'id')
    result = {}
    for movie in movies
      delete movie.showtimes
      movie.external_id = movie.id
      result[movie.id] = movie
      # delete movie.imdb
      # delete movie.trailer
    sails.log.debug 'fetchMoviesFromTheaters:finish'
    result

  fetchMoviesInfo: (movies, callback)->
    sails.log.debug 'fetchMoviesInfo:start'
    result = {}
    for id, movie of movies
      @searchMovieInfo movie, (data)->
        result[data.external_id] = data
        if Object.keys(result).length is Object.keys(movies).length
          sails.log.debug 'fetchMoviesInfo:finish'
          callback result

  searchMovieInfo: (movie, callback)->
    sails.log.debug 'searchMovieInfo:start', movie.name
    tmdb.searchMovie {
      query: movie.name
      language: 'es'
    }, (err, data)->
      _.merge(movie, data.results[0])
      sails.log.debug 'searchMovieInfo:finish'
      callback movie

module.exports = new TheatersController
