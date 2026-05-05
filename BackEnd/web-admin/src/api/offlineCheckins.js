import request from './request'

export const getOfflineCheckins = (params) => request.get('/offline-checkins', { params })
export const syncOfflineCheckins = () => request.post('/offline-checkins/sync')
