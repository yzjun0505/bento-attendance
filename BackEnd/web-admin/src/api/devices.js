import request from '@/api/request'

export function getDevices(params) {
  return request({
    url: '/devices',
    method: 'get',
    params
  })
}

export function createDevice(data) {
  return request({
    url: '/devices',
    method: 'post',
    data
  })
}

export function updateDevice(id, data) {
  return request({
    url: `/devices/${id}`,
    method: 'put',
    data
  })
}

export function deleteDevice(id) {
  return request({
    url: `/devices/${id}`,
    method: 'delete'
  })
}
