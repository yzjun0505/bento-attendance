import request from './request'

export const getShifts = (params) => request.get('/shifts', { params })
export const getShiftById = (id) => request.get(`/shifts/${id}`)
export const createShift = (data) => request.post('/shifts', data)
export const updateShift = (id, data) => request.put(`/shifts/${id}`, data)
export const deleteShift = (id) => request.delete(`/shifts/${id}`)
