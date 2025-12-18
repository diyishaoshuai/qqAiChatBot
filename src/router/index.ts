import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      redirect: '/dashboard'
    },
    {
      path: '/dashboard',
      name: 'Dashboard',
      component: () => import('../views/Dashboard.vue'),
      meta: { title: '仪表盘' }
    },
    {
      path: '/config',
      name: 'Config',
      component: () => import('../views/Config.vue'),
      meta: { title: '配置管理' }
    },
    {
      path: '/personas',
      name: 'Personas',
      component: () => import('../views/Personas.vue'),
      meta: { title: '人格管理' }
    },
    {
      path: '/records',
      name: 'Records',
      component: () => import('../views/Records.vue'),
      meta: { title: '消息记录' }
    },
    {
      path: '/records/:userId',
      name: 'ChatDetail',
      component: () => import('../views/ChatDetail.vue'),
      meta: { title: '聊天详情' }
    }
  ]
})

export default router
