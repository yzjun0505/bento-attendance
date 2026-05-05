import request from './request'

export const getHolidays = (year) => request.get('/holidays', { params: { year } })
export const createHoliday = (data) => request.post('/holidays', data)
export const batchCreateHolidays = (data) => request.post('/holidays/batch', data)
export const updateHoliday = (id, data) => request.put(`/holidays/${id}`, data)
export const deleteHoliday = (id) => request.delete(`/holidays/${id}`)
export const checkDate = (date) => request.get('/holidays/check', { params: { date } })
