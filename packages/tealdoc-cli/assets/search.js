let scripts = document.getElementsByTagName('script')

let path = scripts[scripts.length - 1].src.split('?')[0]

let dir = path.split('/')
    .slice(0, -1)
    .join('/') + '/'

let resultsDropdown
let dropdownElement
let resultsElement
let searchElement
let searchForm
let fuse

function dropdown() {
    dropdownElement.classList.toggle('hidden')
}

function search(text) {
    let results = fuse.search(text)

    if (results.length > 0) {
        let code = results.slice(0, 5).map((v) => {
            return `
            <li class="block px-4 py-2 text-gray-700">
                <a href="${dir}../${v.item.url || '#'}">
                    <h4 class="text-md">${v.item.name}</h4>
                    <p class="text-sm">${v.item.description.match(/(.*)\n|(.*)/)[0]}</p>
                </a>
            </li>
            `
        })

        resultsElement.innerHTML = code.join('\n')
        resultsDropdown.classList.remove('hidden')
    } else {
        resultsElement.innerHTML = ''
        resultsDropdown.classList.add('hidden')
    }
}

window.addEventListener('load', async () => {
    dropdownElement = document.getElementById('dropdown')
    resultsElement = document.getElementById('results')
    searchElement = document.getElementById('search-box')
    resultsDropdown = document.getElementById('results-parent')
    searchForm = document.getElementById('search-form')

    searchElement.addEventListener('keyup', () => {
        search(searchElement.value)
    })

    searchForm.addEventListener('submit', (e) => {
        e.preventDefault()

        search(searchElement.value)
    })

    let res = await fetch(`${dir}indexes.json`)

    let indexes = await res.json()

    fuse = new Fuse(indexes, {
        keys: [
            "kind",
            "name",
            "description"
        ]
    })
})

window.addEventListener('click', (e) => {
    if (!e.target.classList.contains('dropdown-btn')) {
        dropdownElement.classList.add('hidden')
    }

    if (!e.target.classList.contains('search-area')) {
        resultsDropdown.classList.add('hidden')
    }
})
