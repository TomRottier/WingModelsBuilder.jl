using DelimitedFiles, DataInterpolations

function process_data(le_file, te_file, out_fn)
    le = readdlm(le_file, ',')
    te = readdlm(te_file, ',')

    tip = (le[end, 2] + te[end, 2]) / 2
    le = vcat(le, [1.0 tip])
    te = vcat(te, [1.0 tip])

    le_spl = BSplineInterpolation(-le[:, 2] .- 0.25*(le[1, 2] - te[1, 2]), le[:, 1], 3, :ArcLen, :Average; extrapolation=ExtrapolationType.Linear)
    te_spl = BSplineInterpolation(-te[:, 2] .- 0.25*(le[1, 2] - te[1, 2]), te[:, 1], 3, :ArcLen, :Average; extrapolation=ExtrapolationType.Linear)

    ys = range(0.0, 1.0; length=51)
    le2 = le_spl(ys)
    te2 = te_spl(ys)
    writedlm(out_fn, hcat(ys, le2, te2), ',')
    return nothing
end

foreach(["seagull", "merganser", "teal"]) do bird
    le_file = joinpath("data", bird*"_le.csv")
    te_file = joinpath("data", bird*"_te.csv")
    out_fn = joinpath("data", bird * ".csv")

    process_data(le_file, te_file, out_fn)
end