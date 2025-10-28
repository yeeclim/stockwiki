import('./api/stock-search.js').then(module => {
  const handler = module.default;
  
  handler({
    query: { keyword: '대창솔루션', limit: 1 }
  }, {
    setHeader: () => {},
    status: (code) => ({
      json: (data) => console.log(JSON.stringify(data, null, 2))
    })
  });
}).catch(console.error);
