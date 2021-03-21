let previous =  localStorage.getItem('selected') ? localStorage.getItem('selected') : 'Pages'

function update() {
    let selected = window.location.hash ? window.location.hash.substring(1) : previous

    if (!(selected == 'Pages' || selected == 'Modules')) {
        return 
    }

    if (previous == 'Pages' || previous == 'Modules') {
        let element = document.getElementById(previous + '-link')
        let details = document.getElementById(previous + '-section')

        element.classList.remove('text-white')
        details.classList.add('hidden')
    } else if (previous) {
        previous = 'Pages'
    }

    previous = selected

    localStorage.setItem('selected', selected)

    let element = document.getElementById(selected + '-link')
    let details = document.getElementById(previous + '-section')

    element.classList.add('text-white')
    details.classList.remove('hidden')
}

function openSidebar() {
    let sidebar = document.getElementById('sidebar')

    sidebar.classList.toggle('hidden')
    sidebar.classList.toggle('table-cell')
}

window.addEventListener('load', update)
window.addEventListener('hashchange', update)
