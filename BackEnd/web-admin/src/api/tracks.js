import request from './request'

export const getTrack = (userId, date) => request.get(`/tracks/${userId}`, { params: { date } })
export const getHeatmap = (params) => request.get('/tracks/heatmap', { params })
